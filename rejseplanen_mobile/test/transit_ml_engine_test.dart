import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:rejseplanen_mobile/models/station.dart';
import 'package:rejseplanen_mobile/models/trip.dart';
import 'package:rejseplanen_mobile/services/smart_transit_service.dart';
import 'package:rejseplanen_mobile/services/transit_ml_engine.dart';

void main() {
  group('TransitMlEngine - On-Device ML Tests', () {
    test('LinUCBRanker updates inverse covariance via Sherman-Morrison and shifts posterior weights', () {
      final ranker = LinUCBRanker(
        dim: TransitMlEngine.featureDim,
        priors: TransitMlEngine.defaultPriors,
      );

      final initialWeights = ranker.posteriorWeights;
      expect(initialWeights.length, TransitMlEngine.featureDim);

      // Suppose user repeatedly chooses Metro-heavy trip over Bus-heavy trip
      final metroTripFeat = <double>[0.3, 0.0, 0.1, 0.9, 0.0, 0.0, 0.0, 0.0, 0.8, 0.0, 0.0, 0.0];
      final busTripFeat = <double>[0.2, 0.0, 0.1, 0.0, 0.0, 0.0, 0.9, 0.0, 0.8, 0.0, 0.0, 0.0];

      final initialDiff = ranker.score(metroTripFeat, includeExploration: false) -
          ranker.score(busTripFeat, includeExploration: false);

      for (int i = 0; i < 8; i++) {
        ranker.updatePairwise(metroTripFeat, busTripFeat);
      }

      final updatedWeights = ranker.posteriorWeights;
      final updatedDiff = ranker.score(metroTripFeat, includeExploration: false) -
          ranker.score(busTripFeat, includeExploration: false);

      expect(updatedWeights[3], greaterThan(initialWeights[3])); // Metro weight increased
      expect(updatedWeights[6], lessThan(initialWeights[6])); // Bus weight decreased
      expect(updatedDiff, greaterThan(initialDiff));
    });

    test('PairwiseMlpRankNet backpropagation reduces pairwise cross-entropy loss on non-linear preferences', () {
      final mlp = PairwiseMlpRankNet(
        inputDim: TransitMlEngine.featureDim,
        hiddenDim: TransitMlEngine.hiddenDim,
      );

      final posFeat = <double>[0.4, 0.0, 0.15, 0.85, 0.0, 0.0, 0.0, 0.0, 0.95, 0.0, 0.0, 0.0];
      final negFeat = <double>[0.1, 0.67, 0.10, 0.0, 0.90, 0.0, 0.0, 0.48, 0.95, 0.0, 0.63, 0.2];

      final initialLoss = mlp.trainPair(xPos: posFeat, xNeg: negFeat, learningRate: 0.04);
      double finalLoss = initialLoss;
      for (int step = 0; step < 25; step++) {
        finalLoss = mlp.trainPair(xPos: posFeat, xNeg: negFeat, learningRate: 0.04);
      }

      expect(finalLoss, lessThan(initialLoss));
      expect(mlp.forward(posFeat), greaterThan(mlp.forward(negFeat)));
    });

    test('MarkovTransitionModel learns station transitions and sequential chains', () {
      final markov = MarkovTransitionModel();
      final nowMs = DateTime(2026, 10, 17, 8, 30).millisecondsSinceEpoch;

      markov.recordTransition('København H', 'Nørreport St.', weight: 2.5, timestampMs: nowMs);
      markov.recordTransition('København H', 'Nørreport St.', weight: 2.5, timestampMs: nowMs + 60000);
      markov.recordTransition('København H', 'Østerport St.', weight: 1.0, timestampMs: nowMs + 120000);

      final pNorreport = markov.transitionProbability('København H', 'Nørreport St.');
      final pOsterport = markov.transitionProbability('København H', 'Østerport St.');

      expect(pNorreport, greaterThan(pOsterport));
      expect(
        markov.isSequentialChainContinuation('Østerport St.', nowMs + 3600 * 1000),
        isTrue,
      );
    });

    test('SmartTransitService end-to-end learning, scoring, and SharedPreferences persistence', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final service = SmartTransitService();
      await service.loadFromPrefs(prefs);

      final fastBusWithTransfer = TripProposal(
        idx: '1',
        depTime: '08:00',
        arrTime: '08:22',
        durationMin: 22,
        changes: 2,
        legs: [
          TripLeg(
            name: 'Bus 5C',
            type: 'BUS',
            origin: TripStop(name: 'København H', time: '08:00', rtTime: '08:03', date: '17.10.26', track: ''),
            destination: TripStop(name: 'Rådhuspladsen', time: '08:08', rtTime: '08:11', date: '17.10.26', track: ''),
          ),
          TripLeg(
            name: 'Bus 2A',
            type: 'BUS',
            origin: TripStop(name: 'Rådhuspladsen', time: '08:12', rtTime: '08:12', date: '17.10.26', track: ''),
            destination: TripStop(name: 'Nørreport St.', time: '08:22', rtTime: '08:22', date: '17.10.26', track: ''),
          ),
        ],
      );

      final directMetro = TripProposal(
        idx: '2',
        depTime: '08:02',
        arrTime: '08:27',
        durationMin: 25,
        changes: 0,
        legs: [
          TripLeg(
            name: 'Metro M3',
            type: 'M',
            origin: TripStop(name: 'København H', time: '08:02', rtTime: '08:02', date: '17.10.26', track: '1'),
            destination: TripStop(name: 'Nørreport St.', time: '08:27', rtTime: '08:27', date: '17.10.26', track: '1'),
          ),
        ],
      );

      final candidates = [fastBusWithTransfer, directMetro];
      for (int i = 0; i < 6; i++) {
        service.learnFromTripSelection(directMetro, candidates);
      }

      final scored = service.scoreProposals(candidates);
      expect(scored.length, 2);
      expect(scored[1].isSmartPick, isTrue);
      expect(scored[1].confidence, greaterThan(scored[0].confidence));

      await service.saveToPrefs(prefs);

      final restored = SmartTransitService();
      await restored.loadFromPrefs(prefs);
      expect(restored.learnedSamplesCount, 6);
      final restoredScored = restored.scoreProposals(candidates);
      expect(restoredScored[1].isSmartPick, isTrue);
    });
  });
}
