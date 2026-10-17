## v1.2.4 更新内容 / What's New

### 🇨🇳 中文
- **端侧混合在线机器学习引擎 (`TransitMlEngine`)**：
  - **12 维时空上下文特征提取**：融合早晚高峰双峰高斯强度、非高峰/周末状态、实时晚点强度以及**高峰期 × 换乘次数**非线性交叉特征。
  - **多维上下文赌博机 (`LinUCBRanker`)**：基于 Sherman-Morrison 秩-1 逆协方差更新（$O(d^2)$）与上置信界（UCB）动态平衡习惯利用与新路线探索。
  - **双层神经网络 (`PairwiseMlpRankNet`)**：内置 $12 \rightarrow 16 \rightarrow 1$（LeakyReLU 激活）成对排序网络，基于动量（Momentum）与 L2 正则化在线反向传播学习个人乘车偏好，并通过 Softmax 输出校准后的方案置信度。
  - **一阶马尔可夫出行链 (`MarkovTransitionModel`)**：学习站点间有向转移概率与连续出行链（$A \rightarrow B \rightarrow C$），提升常走路线与返程推荐准确度。
- **端侧智能学习管理面板**：在设置页新增三语（中 / 英 / 丹麦语）端侧机器学习状态展示与一键重置功能，100% 离线运行并保护隐私。

### 🇬🇧 English
- **Hybrid On-Device Machine Learning Engine (`TransitMlEngine`)**:
  - **12D Spatio-Temporal Feature Extraction**: Captures rush-hour bimodal Gaussian intensity, off-peak/weekend context, real-time delay intensity, and non-linear **rush-hour × transfer** interactions.
  - **Contextual Bandit (`LinUCBRanker`)**: Uses exact $O(d^2)$ Sherman-Morrison inverse covariance updates and Upper Confidence Bound (UCB) exploration.
  - **Two-Layer Neural Network (`PairwiseMlpRankNet`)**: Implements an online $12 \rightarrow 16 \rightarrow 1$ LeakyReLU neural network trained via pairwise RankNet backpropagation with momentum and Softmax confidence calibration.
  - **1st-Order Markov Commute Chain (`MarkovTransitionModel`)**: Learns directed station-to-station transition probabilities and sequential trip continuations ($A \rightarrow B \rightarrow C$).
- **On-Device ML Settings Card**: View trained sample counts and reset learned preferences anytime in Settings (100% offline & privacy-preserving).

### 🇩🇰 Dansk
- **Hybrid maskinlæringsmotor på enheden (`TransitMlEngine`)**:
  - **12D kontekstuel egenskabsudtrækning**: Inddrager myldretidsintensitet, forsinkelsesgrad og ikke-lineære krydseffekter mellem myldretid og skift.
  - **Kontekstuel Bandit (`LinUCBRanker`) & 2-lags Neuralt Netværk (`PairwiseMlpRankNet`)**: Lærer dine rejse- og skiftevaner 100% offline på telefonen med parvis RankNet-backpropagation og Markov-kæder for rejser ($A \rightarrow B \rightarrow C$).
- **ML-administration i Indstillinger**: Se antal trænede valg og nulstil ML-modellen direkte under Indstillinger.
