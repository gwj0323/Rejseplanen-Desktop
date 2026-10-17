import 'dart:math' as math;

/// Hybrid On-Device Machine Learning Engine for Personalized Transit Ranking
/// & Sequential Commute Prediction.
///
/// Combines three lightweight, privacy-preserving on-device models:
/// 1. [LinUCBRanker]: Contextual Bandit with Ridge Regression & exact
///    Sherman-Morrison rank-1 inverse covariance updates ($O(d^2)$).
/// 2. [PairwiseMlpRankNet]: 2-Layer Neural Network ($12 \rightarrow 16 \rightarrow 1$)
///    with LeakyReLU activations and online pairwise RankNet backpropagation
///    with momentum.
/// 3. [MarkovTransitionModel]: First-order spatio-temporal Markov chain for
///    station-to-station transition probability estimation.
class TransitMlEngine {
  static const int featureDim = 12;
  static const int hiddenDim = 16;

  /// Domain prior weights for the 12 contextual features:
  ///  [0] normDuration              (-1.25)
  ///  [1] normTransfers             (-0.80)
  ///  [2] walkRatio                 (-0.45)
  ///  [3] metroRatio                (+0.25)
  ///  [4] stogRatio                 (+0.20)
  ///  [5] trainRatio                (+0.15)
  ///  [6] busRatio                  (-0.10)
  ///  [7] riskPenalty               (-0.95)
  ///  [8] rushHourIntensity         (-0.10)
  ///  [9] offPeakWeekend            (+0.05)
  /// [10] rushTransferInteraction   (-0.55)
  /// [11] delayIntensity            (-0.70)
  static const List<double> defaultPriors = [
    -1.25,
    -0.80,
    -0.45,
    0.25,
    0.20,
    0.15,
    -0.10,
    -0.95,
    -0.10,
    0.05,
    -0.55,
    -0.70,
  ];

  final LinUCBRanker linUcb;
  final PairwiseMlpRankNet mlp;
  final MarkovTransitionModel markov;

  int _totalTrainingSteps = 0;
  double _emaPairwiseLoss = 0.6931; // ln(2) initial baseline

  TransitMlEngine({
    LinUCBRanker? linUcb,
    PairwiseMlpRankNet? mlp,
    MarkovTransitionModel? markov,
  })  : linUcb = linUcb ?? LinUCBRanker(dim: featureDim, priors: defaultPriors),
        mlp = mlp ?? PairwiseMlpRankNet(inputDim: featureDim, hiddenDim: hiddenDim),
        markov = markov ?? MarkovTransitionModel();

  int get totalTrainingSteps => _totalTrainingSteps;
  double get emaPairwiseLoss => _emaPairwiseLoss;

  /// Effective linear preference weights (posterior mean $\hat{\theta} = A^{-1} b$)
  List<double> get posteriorWeights => linUcb.posteriorWeights;

  /// Reset all learned parameters back to clean cold-start priors
  void reset() {
    linUcb.reset(defaultPriors);
    mlp.reset();
    markov.reset();
    _totalTrainingSteps = 0;
    _emaPairwiseLoss = 0.6931;
  }

  /// Compute ensemble utility score for a 12-dimensional contextual feature vector.
  ///
  /// Blends the Contextual Bandit UCB score (linear exploitation + uncertainty
  /// exploration) with the non-linear 2-layer MLP RankNet score.
  double scoreFeatureVector(List<double> x, {bool includeExploration = true}) {
    final ucbScore = linUcb.score(x, includeExploration: includeExploration);
    final mlpScore = mlp.forward(x);

    // Adaptive gating: smoothly increase non-linear MLP weight up to 0.45
    // as online training samples accumulate.
    final mlpGate = math.min(0.45, 0.04 * _totalTrainingSteps);
    return (1.0 - mlpGate) * ucbScore + mlpGate * mlpScore;
  }

  /// Convert raw candidate scores into calibrated selection probabilities via Softmax.
  List<double> computeSoftmaxProbabilities(List<double> scores, {double temperature = 0.65}) {
    if (scores.isEmpty) return const [];
    if (scores.length == 1) return const [1.0];

    double maxS = scores.first;
    for (final s in scores) {
      if (s > maxS) maxS = s;
    }

    final exps = List<double>.filled(scores.length, 0.0);
    double sumExp = 0.0;
    final invTemp = 1.0 / math.max(0.1, temperature);
    for (int i = 0; i < scores.length; i++) {
      final e = math.exp(((scores[i] - maxS) * invTemp).clamp(-20.0, 20.0));
      exps[i] = e;
      sumExp += e;
    }
    if (sumExp <= 0.0) {
      return List<double>.filled(scores.length, 1.0 / scores.length);
    }
    return exps.map((e) => e / sumExp).toList();
  }

  /// Perform an online pairwise learning step given the chosen feature vector
  /// and the list of unchosen candidate feature vectors.
  void trainPairwise({
    required List<double> chosenFeatures,
    required List<List<double>> unchosenCandidates,
  }) {
    if (unchosenCandidates.isEmpty) return;

    // 1. Update Contextual Bandit (LinUCB) against the mean of rejected alternatives
    //    and individual hard negatives
    final avgRejected = List<double>.filled(featureDim, 0.0);
    for (final neg in unchosenCandidates) {
      for (int j = 0; j < featureDim; j++) {
        avgRejected[j] += neg[j];
      }
    }
    for (int j = 0; j < featureDim; j++) {
      avgRejected[j] /= unchosenCandidates.length;
    }

    linUcb.updatePairwise(chosenFeatures, avgRejected);

    // 2. Train 2-Layer Neural RankNet via pairwise backpropagation across candidates
    double stepLoss = 0.0;
    for (final neg in unchosenCandidates) {
      stepLoss += mlp.trainPair(
        xPos: chosenFeatures,
        xNeg: neg,
        learningRate: 0.035 / math.sqrt(1.0 + 0.02 * _totalTrainingSteps),
      );
    }
    stepLoss /= unchosenCandidates.length;

    _emaPairwiseLoss = 0.9 * _emaPairwiseLoss + 0.1 * stepLoss;
    _totalTrainingSteps++;
  }

  /// Migrate legacy 8-dimensional linear weight vector from v1 storage if present
  void importLegacyWeights(List<double> legacy8Weights, int legacySamples) {
    if (legacy8Weights.length < 8) return;
    final migrated = List<double>.from(defaultPriors);
    for (int i = 0; i < 8; i++) {
      migrated[i] = legacy8Weights[i];
    }
    linUcb.reset(migrated);
    _totalTrainingSteps = math.max(_totalTrainingSteps, legacySamples);
  }

  Map<String, dynamic> toJson() => {
        'version': 2,
        'steps': _totalTrainingSteps,
        'emaLoss': _emaPairwiseLoss,
        'linUcb': linUcb.toJson(),
        'mlp': mlp.toJson(),
        'markov': markov.toJson(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _totalTrainingSteps = (json['steps'] as num?)?.toInt() ?? 0;
    _emaPairwiseLoss = (json['emaLoss'] as num?)?.toDouble() ?? 0.6931;
    if (json['linUcb'] is Map) {
      linUcb.loadFromJson(Map<String, dynamic>.from(json['linUcb']));
    }
    if (json['mlp'] is Map) {
      mlp.loadFromJson(Map<String, dynamic>.from(json['mlp']));
    }
    if (json['markov'] is Map) {
      markov.loadFromJson(Map<String, dynamic>.from(json['markov']));
    }
  }
}

/// Disjoint / Ridge Contextual Bandit Ranker (LinUCB) with exact
/// Sherman-Morrison $O(d^2)$ inverse covariance updates.
class LinUCBRanker {
  final int dim;
  late List<double> _aInv; // Flattened dim x dim inverse covariance matrix A^-1
  late List<double> _b; // dim-length reward-weighted feature accumulator
  late List<double> _priors;
  int _updates = 0;

  static const List<double> _minBounds = [
    -3.2, // normDuration
    -2.6, // normTransfers
    -2.2, // walkRatio
    -1.0, // metroRatio
    -1.0, // stogRatio
    -1.0, // trainRatio
    -1.2, // busRatio
    -2.6, // riskPenalty
    -1.5, // rushHourIntensity
    -1.0, // offPeakWeekend
    -2.0, // rushTransferInteraction
    -2.2, // delayIntensity
  ];

  static const List<double> _maxBounds = [
    -0.15, // normDuration (always prefer shorter or equal)
    -0.05, // normTransfers
    0.25, // walkRatio
    1.6, // metroRatio
    1.6, // stogRatio
    1.6, // trainRatio
    1.3, // busRatio
    -0.10, // riskPenalty
    0.8, // rushHourIntensity
    0.8, // offPeakWeekend
    0.1, // rushTransferInteraction
    -0.05, // delayIntensity
  ];

  LinUCBRanker({
    required this.dim,
    required List<double> priors,
  }) {
    reset(priors);
  }

  void reset(List<double> priors) {
    _priors = List<double>.generate(
      dim,
      (i) => i < priors.length ? priors[i] : 0.0,
    );
    _aInv = List<double>.filled(dim * dim, 0.0);
    for (int i = 0; i < dim; i++) {
      _aInv[i * dim + i] = 1.0; // Identity matrix I_d (Ridge lambda = 1.0)
    }
    _b = List<double>.filled(dim, 0.0);
    _updates = 0;
  }

  /// Posterior weight estimate $\hat{\theta} = \text{clamp}(\theta_0 + A^{-1} b)$
  List<double> get posteriorWeights {
    final theta = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) {
      double sum = _priors[i];
      final rowOffset = i * dim;
      for (int j = 0; j < dim; j++) {
        sum += _aInv[rowOffset + j] * _b[j];
      }
      final lo = i < _minBounds.length ? _minBounds[i] : -3.0;
      final hi = i < _maxBounds.length ? _maxBounds[i] : 3.0;
      theta[i] = sum.clamp(lo, hi);
    }
    return theta;
  }

  /// Compute LinUCB score: $\hat{\theta}^\top x + \alpha_t \sqrt{x^\top A^{-1} x}$
  double score(List<double> x, {bool includeExploration = true}) {
    final theta = posteriorWeights;
    double mean = 0.0;
    final len = math.min(dim, x.length);
    for (int i = 0; i < len; i++) {
      mean += theta[i] * x[i];
    }
    if (!includeExploration) return mean;

    // Compute quadratic form x^T A^-1 x for epistemic uncertainty
    double quad = 0.0;
    for (int i = 0; i < len; i++) {
      double rowSum = 0.0;
      final rowOffset = i * dim;
      for (int j = 0; j < len; j++) {
        rowSum += _aInv[rowOffset + j] * x[j];
      }
      quad += x[i] * rowSum;
    }

    // Exploration coefficient decays smoothly as user history grows
    final alpha = 0.14 / math.sqrt(1.0 + 0.18 * _updates);
    final ucbBonus = alpha * math.sqrt(math.max(0.0, quad));
    return mean + ucbBonus;
  }

  /// Exact Sherman-Morrison rank-1 inverse covariance update on pairwise difference
  /// $\Delta x = x_{\text{chosen}} - x_{\text{rejected}}$
  void updatePairwise(List<double> xChosen, List<double> xRejected) {
    final dx = List<double>.filled(dim, 0.0);
    double normSq = 0.0;
    for (int i = 0; i < dim && i < xChosen.length && i < xRejected.length; i++) {
      dx[i] = xChosen[i] - xRejected[i];
      normSq += dx[i] * dx[i];
    }
    if (normSq < 1e-8) return;

    // u = A^-1 * dx
    final u = List<double>.filled(dim, 0.0);
    for (int i = 0; i < dim; i++) {
      double s = 0.0;
      final rowOffset = i * dim;
      for (int j = 0; j < dim; j++) {
        s += _aInv[rowOffset + j] * dx[j];
      }
      u[i] = s;
    }

    // denom = 1 + dx^T * u
    double denom = 1.0;
    for (int i = 0; i < dim; i++) {
      denom += dx[i] * u[i];
    }

    if (denom > 1e-6) {
      // Gently inflate covariance (forgetting factor) so model adapts to
      // seasonal / changing user habits without covariance collapse
      const double forgetInv = 1.005;
      final invDenom = 1.0 / denom;
      for (int i = 0; i < dim; i++) {
        final rowOffset = i * dim;
        for (int j = 0; j < dim; j++) {
          final updated = (_aInv[rowOffset + j] - (u[i] * u[j]) * invDenom) * forgetInv;
          _aInv[rowOffset + j] = updated.clamp(-5.0, 5.0);
        }
        // Keep diagonal strictly positive
        if (_aInv[rowOffset + i] < 0.05) {
          _aInv[rowOffset + i] = 0.05;
        }
      }
    }

    // Update reward residual accumulator b with mild L2 decay towards zero
    const double stepGain = 0.45;
    const double decay = 0.015;
    for (int i = 0; i < dim; i++) {
      _b[i] = (1.0 - decay) * _b[i] + stepGain * dx[i];
    }
    _updates++;
  }

  Map<String, dynamic> toJson() => {
        'updates': _updates,
        'aInv': _aInv.map((v) => double.parse(v.toStringAsFixed(5))).toList(),
        'b': _b.map((v) => double.parse(v.toStringAsFixed(5))).toList(),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _updates = (json['updates'] as num?)?.toInt() ?? 0;
    if (json['aInv'] is List) {
      final list = (json['aInv'] as List).map((e) => (e as num).toDouble()).toList();
      if (list.length == dim * dim) {
        _aInv = list;
      }
    }
    if (json['b'] is List) {
      final list = (json['b'] as List).map((e) => (e as num).toDouble()).toList();
      if (list.length == dim) {
        _b = list;
      }
    }
  }
}

/// Two-Layer Neural Network (Pairwise RankNet MLP: $12 \rightarrow 16 \rightarrow 1$)
/// trained online with LeakyReLU activations, L2 weight decay, and SGD with Momentum.
class PairwiseMlpRankNet {
  final int inputDim;
  final int hiddenDim;

  late List<double> _w1; // hiddenDim * inputDim
  late List<double> _b1; // hiddenDim
  late List<double> _w2; // hiddenDim
  double _b2 = 0.0;

  // Momentum buffers
  late List<double> _mW1;
  late List<double> _mB1;
  late List<double> _mW2;

  static const double _leakySlope = 0.1;

  PairwiseMlpRankNet({
    required this.inputDim,
    required this.hiddenDim,
  }) {
    reset();
  }

  /// Deterministic Xavier/He initialization so cold-start behavior is stable
  void reset() {
    _w1 = List<double>.filled(hiddenDim * inputDim, 0.0);
    _b1 = List<double>.filled(hiddenDim, 0.0);
    _w2 = List<double>.filled(hiddenDim, 0.0);
    _b2 = 0.0;

    _mW1 = List<double>.filled(hiddenDim * inputDim, 0.0);
    _mB1 = List<double>.filled(hiddenDim, 0.0);
    _mW2 = List<double>.filled(hiddenDim, 0.0);

    // Deterministic pseudo-orthogonal initialization using golden-ratio phase
    final scale1 = math.sqrt(2.0 / (inputDim + hiddenDim)) * 0.35;
    final scale2 = math.sqrt(2.0 / hiddenDim) * 0.25;

    for (int i = 0; i < hiddenDim; i++) {
      for (int j = 0; j < inputDim; j++) {
        final idx = i * inputDim + j;
        final phase = (idx + 1) * 0.618033988749895;
        final pseudoRand = math.sin(phase * 2.0 * math.pi);
        _w1[idx] = pseudoRand * scale1;
      }
      final phase2 = (i + 1) * 1.324717957244746;
      _w2[i] = math.cos(phase2 * 2.0 * math.pi) * scale2;
    }
  }

  /// Forward pass returning scalar utility score $s(x)$
  double forward(List<double> x) {
    final len = math.min(inputDim, x.length);
    double out = _b2;
    for (int i = 0; i < hiddenDim; i++) {
      double z = _b1[i];
      final rowOffset = i * inputDim;
      for (int j = 0; j < len; j++) {
        z += _w1[rowOffset + j] * x[j];
      }
      final h = z >= 0.0 ? z : _leakySlope * z;
      out += _w2[i] * h;
    }
    return out.clamp(-6.0, 6.0);
  }

  /// Online Pairwise RankNet Backpropagation step for a (positive, negative) pair.
  /// Returns the pairwise cross-entropy loss $-\ln \sigma(s^+ - s^-)$.
  double trainPair({
    required List<double> xPos,
    required List<double> xNeg,
    double learningRate = 0.03,
  }) {
    final len = math.min(inputDim, math.min(xPos.length, xNeg.length));

    final zPos = List<double>.filled(hiddenDim, 0.0);
    final hPos = List<double>.filled(hiddenDim, 0.0);
    final zNeg = List<double>.filled(hiddenDim, 0.0);
    final hNeg = List<double>.filled(hiddenDim, 0.0);

    double sPos = _b2;
    double sNeg = _b2;

    for (int i = 0; i < hiddenDim; i++) {
      double zp = _b1[i];
      double zn = _b1[i];
      final rowOffset = i * inputDim;
      for (int j = 0; j < len; j++) {
        final w = _w1[rowOffset + j];
        zp += w * xPos[j];
        zn += w * xNeg[j];
      }
      zPos[i] = zp;
      zNeg[i] = zn;
      final hp = zp >= 0.0 ? zp : _leakySlope * zp;
      final hn = zn >= 0.0 ? zn : _leakySlope * zn;
      hPos[i] = hp;
      hNeg[i] = hn;
      sPos += _w2[i] * hp;
      sNeg += _w2[i] * hn;
    }

    final margin = (sPos - sNeg).clamp(-12.0, 12.0);
    final prob = 1.0 / (1.0 + math.exp(-margin));
    final loss = -math.log(math.max(1e-7, prob));

    // dL / d(margin) = sigma(sPos - sNeg) - 1  (negative scalar)
    final gradMargin = prob - 1.0;

    const double momentum = 0.82;
    const double weightDecay = 0.004;

    for (int i = 0; i < hiddenDim; i++) {
      final w2Old = _w2[i];

      // Hidden layer gradients via chain rule through LeakyReLU
      final dActPos = zPos[i] >= 0.0 ? 1.0 : _leakySlope;
      final dActNeg = zNeg[i] >= 0.0 ? 1.0 : _leakySlope;

      final deltaPos = gradMargin * w2Old * dActPos;
      final deltaNeg = -gradMargin * w2Old * dActNeg;

      // Update W1 row i
      final rowOffset = i * inputDim;
      for (int j = 0; j < len; j++) {
        final idx = rowOffset + j;
        final gW1 = deltaPos * xPos[j] + deltaNeg * xNeg[j] + weightDecay * _w1[idx];
        _mW1[idx] = momentum * _mW1[idx] + (1.0 - momentum) * gW1;
        _w1[idx] = (_w1[idx] - learningRate * _mW1[idx]).clamp(-2.5, 2.5);
      }

      // Update b1[i]
      final gB1 = deltaPos + deltaNeg + weightDecay * _b1[i];
      _mB1[i] = momentum * _mB1[i] + (1.0 - momentum) * gB1;
      _b1[i] = (_b1[i] - learningRate * _mB1[i]).clamp(-1.5, 1.5);

      // Update w2[i]
      final gW2 = gradMargin * (hPos[i] - hNeg[i]) + weightDecay * w2Old;
      _mW2[i] = momentum * _mW2[i] + (1.0 - momentum) * gW2;
      _w2[i] = (_w2[i] - learningRate * _mW2[i]).clamp(-2.5, 2.5);
    }

    return loss;
  }

  Map<String, dynamic> toJson() => {
        'w1': _w1.map((v) => double.parse(v.toStringAsFixed(5))).toList(),
        'b1': _b1.map((v) => double.parse(v.toStringAsFixed(5))).toList(),
        'w2': _w2.map((v) => double.parse(v.toStringAsFixed(5))).toList(),
        'b2': double.parse(_b2.toStringAsFixed(5)),
      };

  void loadFromJson(Map<String, dynamic> json) {
    if (json['w1'] is List) {
      final list = (json['w1'] as List).map((e) => (e as num).toDouble()).toList();
      if (list.length == hiddenDim * inputDim) _w1 = list;
    }
    if (json['b1'] is List) {
      final list = (json['b1'] as List).map((e) => (e as num).toDouble()).toList();
      if (list.length == hiddenDim) _b1 = list;
    }
    if (json['w2'] is List) {
      final list = (json['w2'] as List).map((e) => (e as num).toDouble()).toList();
      if (list.length == hiddenDim) _w2 = list;
    }
    _b2 = (json['b2'] as num?)?.toDouble() ?? 0.0;
  }
}

/// First-Order Spatio-Temporal Markov Chain for Sequential Commute Transitions.
///
/// Tracks directed station transitions `origin -> dest` and sequential trip chains
/// (`lastDestination -> nextOrigin -> nextDestination`) with exponential decay.
class MarkovTransitionModel {
  /// Nested map: originKey -> { destKey: transitionWeight }
  final Map<String, Map<String, double>> _transitions = {};
  String? _lastDestinationKey;
  int _lastTransitionTimestampMs = 0;

  void reset() {
    _transitions.clear();
    _lastDestinationKey = null;
    _lastTransitionTimestampMs = 0;
  }

  String _normKey(String stationName) => stationName.trim().toLowerCase();

  /// Record a directed transition from [originName] to [destName]
  void recordTransition(
    String originName,
    String destName, {
    double weight = 1.0,
    required int timestampMs,
  }) {
    final oKey = _normKey(originName);
    final dKey = _normKey(destName);
    if (oKey.isEmpty || dKey.isEmpty || oKey == dKey) return;

    // Apply mild global decay so recent transitions carry higher Markov mass
    _transitions.forEach((_, targets) {
      targets.updateAll((_, v) => v * 0.985);
    });

    final targets = _transitions.putIfAbsent(oKey, () => {});
    targets[dKey] = (targets[dKey] ?? 0.0) + weight;

    // Prune tiny weights to bound memory
    if (targets.length > 25) {
      final entries = targets.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      targets
        ..clear()
        ..addEntries(entries.take(20));
    }
    if (_transitions.length > 60) {
      final firstKey = _transitions.keys.first;
      _transitions.remove(firstKey);
    }

    _lastDestinationKey = dKey;
    _lastTransitionTimestampMs = timestampMs;
  }

  /// Compute smoothed Markov transition probability $P(\text{dest} \mid \text{origin})$
  double transitionProbability(String originName, String destName) {
    final oKey = _normKey(originName);
    final dKey = _normKey(destName);
    final targets = _transitions[oKey];
    if (targets == null || targets.isEmpty) return 0.0;

    double total = 0.0;
    for (final w in targets.values) {
      total += w;
    }
    if (total <= 0.0) return 0.0;
    final count = targets[dKey] ?? 0.0;
    if (count <= 0.0) return 0.0;

    // Laplace-smoothed transition probability
    return (count + 0.25) / (total + 0.25 * (targets.length + 1));
  }

  /// Returns true if [originName] matches the destination of the user's most recent
  /// trip within the last 14 hours (sequential trip chain $A \rightarrow B \rightarrow C$).
  bool isSequentialChainContinuation(String originName, int nowMs) {
    if (_lastDestinationKey == null || _lastTransitionTimestampMs <= 0) {
      return false;
    }
    final hoursElapsed = (nowMs - _lastTransitionTimestampMs) / 3600000.0;
    if (hoursElapsed < 0.0 || hoursElapsed > 14.0) return false;
    return _normKey(originName) == _lastDestinationKey;
  }

  Map<String, dynamic> toJson() => {
        'lastDest': _lastDestinationKey,
        'lastTs': _lastTransitionTimestampMs,
        'matrix': _transitions.map(
          (k, v) => MapEntry(
            k,
            v.map((tk, tv) => MapEntry(tk, double.parse(tv.toStringAsFixed(4)))),
          ),
        ),
      };

  void loadFromJson(Map<String, dynamic> json) {
    _lastDestinationKey = json['lastDest'] as String?;
    _lastTransitionTimestampMs = (json['lastTs'] as num?)?.toInt() ?? 0;
    _transitions.clear();
    if (json['matrix'] is Map) {
      final rawMatrix = Map<String, dynamic>.from(json['matrix']);
      rawMatrix.forEach((oKey, targetsRaw) {
        if (targetsRaw is Map) {
          final targetsMap = <String, double>{};
          targetsRaw.forEach((dKey, val) {
            if (val is num) {
              targetsMap[dKey.toString()] = val.toDouble();
            }
          });
          if (targetsMap.isNotEmpty) {
            _transitions[oKey] = targetsMap;
          }
        }
      });
    }
  }
}
