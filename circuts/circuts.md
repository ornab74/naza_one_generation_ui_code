Here are **50 foundational equations used across advanced AI/ML**, spanning deep learning, optimization, probabilistic modeling, generative AI, reinforcement learning, and modern transformers.

### Core mathematics & probability

1. **Bayes' theorem**
   [
   P(A|B)=\frac{P(B|A)P(A)}{P(B)}
   ]

2. **Log-likelihood**
   [
   \mathcal L(\theta)=\sum_i\log p(x_i|\theta)
   ]

3. **Maximum likelihood estimation**
   [
   \hat\theta=\arg\max_\theta\prod_i p(x_i|\theta)
   ]

4. **Entropy**
   [
   H(X)=-\sum_xp(x)\log p(x)
   ]

5. **Cross-entropy**
   [
   H(p,q)=-\sum_xp(x)\log q(x)
   ]

6. **KL divergence**
   [
   D_{KL}(P|Q)=\sum_xP(x)\log\frac{P(x)}{Q(x)}
   ]

7. **Mutual information**
   [
   I(X;Y)=\sum_{x,y}p(x,y)\log\frac{p(x,y)}{p(x)p(y)}
   ]

8. **Gaussian distribution**
   [
   p(x)=\frac{1}{\sqrt{2\pi\sigma^2}}
   e^{-\frac{(x-\mu)^2}{2\sigma^2}}
   ]

9. **Multivariate Gaussian**
   [
   p(x)=\frac{e^{-\frac12(x-\mu)^T\Sigma^{-1}(x-\mu)}}
   {(2\pi)^{d/2}|\Sigma|^{1/2}}
   ]

10. **Jensen–Shannon divergence**
    [
    JS(P,Q)=\frac12D_{KL}(P|M)+\frac12D_{KL}(Q|M)
    ]
    where (M=(P+Q)/2).

### Neural networks

11. **Neuron / affine transformation**
    [
    z=Wx+b
    ]

12. **ReLU**
    [
    ReLU(x)=\max(0,x)
    ]

13. **Sigmoid**
    [
    \sigma(x)=\frac{1}{1+e^{-x}}
    ]

14. **Tanh**
    [
    \tanh(x)=\frac{e^x-e^{-x}}{e^x+e^{-x}}
    ]

15. **Softmax**
    [
    softmax(z_i)=\frac{e^{z_i}}{\sum_j e^{z_j}}
    ]

16. **Multiclass cross-entropy loss**
    [
    \mathcal L=-\sum_i y_i\log\hat y_i
    ]

17. **Mean squared error**
    [
    MSE=\frac1n\sum_i(y_i-\hat y_i)^2
    ]

18. **Backpropagation**
    [
    \frac{\partial L}{\partial w}
    =
    \frac{\partial L}{\partial y}
    \frac{\partial y}{\partial w}
    ]

19. **Gradient descent**
    [
    \theta_{t+1}=\theta_t-\eta\nabla_\theta L(\theta_t)
    ]

20. **Chain rule**
    [
    \frac{\partial f}{\partial x}
    =
    \frac{\partial f}{\partial g}
    \frac{\partial g}{\partial x}
    ]

### Optimization

21. **Stochastic gradient descent**
    [
    \theta_{t+1}=\theta_t-\eta\nabla_\theta L(\theta_t;x_b)
    ]

22. **Momentum**
    [
    v_t=\beta v_{t-1}+(1-\beta)g_t
    ]
    [
    \theta_t=\theta_{t-1}-\eta v_t
    ]

23. **Adam first moment**
    [
    m_t=\beta_1m_{t-1}+(1-\beta_1)g_t
    ]

24. **Adam second moment**
    [
    v_t=\beta_2v_{t-1}+(1-\beta_2)g_t^2
    ]

25. **Adam update**
    [
    \theta_t=\theta_{t-1}
    -\eta\frac{\hat m_t}{\sqrt{\hat v_t}+\epsilon}
    ]

26. **L2 regularization**
    [
    L_{reg}=L+\lambda|\theta|_2^2
    ]

27. **L1 regularization**
    [
    L_{reg}=L+\lambda|\theta|_1
    ]

28. **Newton's method**
    [
    \theta_{t+1}
    =
    \theta_t-H^{-1}\nabla L
    ]
    where (H) is the Hessian.

### Transformers & sequence models

29. **Scaled dot-product attention**
    [
    Attention(Q,K,V)
    =
    softmax\left(\frac{QK^T}{\sqrt{d_k}}\right)V
    ]

30. **Multi-head attention**
    [
    MHA(Q,K,V)=Concat(head_1,\ldots,head_h)W^O
    ]

31. **Attention head**
    [
    head_i=Attention(QW_i^Q,KW_i^K,VW_i^V)
    ]

32. **Transformer residual connection**
    [
    x'=x+Attention(x)
    ]

33. **Layer normalization**
    [
    LayerNorm(x)=
    \gamma\frac{x-\mu}{\sqrt{\sigma^2+\epsilon}}+\beta
    ]

34. **Transformer feed-forward network**
    [
    FFN(x)=W_2,\sigma(W_1x+b_1)+b_2
    ]

35. **Autoregressive language-model probability**
    [
    P(x_{1:T})=\prod_{t=1}^TP(x_t|x_{<t})
    ]

36. **Language-model loss**
    [
    L=-\sum_{t=1}^T\log P(x_t|x_{<t})
    ]

37. **Causal attention mask**
    [
    A_{ij}=
    \begin{cases}
    0,&j\le i\
    -\infty,&j>i
    \end{cases}
    ]

38. **RoPE rotation**
    [
    \begin{pmatrix}
    x'*{2i}\x'*{2i+1}
    \end{pmatrix}
    =
    \begin{pmatrix}
    \cos\theta_i&-\sin\theta_i\
    \sin\theta_i&\cos\theta_i
    \end{pmatrix}
    \begin{pmatrix}
    x_{2i}\x_{2i+1}
    \end{pmatrix}
    ]

### Generative AI

39. **Variational lower bound / ELBO**
    [
    \log p(x)\ge
    E_{q(z|x)}[\log p(x|z)]
    -D_{KL}(q(z|x)|p(z))
    ]

40. **VAE objective**
    [
    L_{VAE}
    =
    -E_{q(z|x)}[\log p(x|z)]
    +D_{KL}(q(z|x)|p(z))
    ]

41. **GAN discriminator objective**
    [
    \max_D
    E_{x\sim p_{data}}\log D(x)

*

E_{z\sim p(z)}\log(1-D(G(z)))
]

42. **GAN generator objective**
    [
    \min_G
    E_{z\sim p(z)}[\log(1-D(G(z)))]
    ]

43. **Diffusion forward process**
    [
    q(x_t|x_{t-1})
    =
    N(\sqrt{1-\beta_t}x_{t-1},\beta_tI)
    ]

44. **Diffusion closed-form noising**
    [
    x_t=
    \sqrt{\bar\alpha_t}x_0+
    \sqrt{1-\bar\alpha_t}\epsilon
    ]

45. **Diffusion denoising objective**
    [
    L=
    E_{t,x_0,\epsilon}
    \left[
    |\epsilon-\epsilon_\theta(x_t,t)|^2
    \right]
    ]

### Reinforcement learning

46. **Expected return**
    [
    G_t=\sum_{k=0}^{\infty}\gamma^kR_{t+k+1}
    ]

47. **Bellman equation**
    [
    V^\pi(s)
    =
    E_\pi[R_{t+1}+\gamma V^\pi(S_{t+1})|S_t=s]
    ]

48. **Q-learning update**
    [
    Q(s,a)\leftarrow
    Q(s,a)+
    \alpha[r+\gamma\max_{a'}Q(s',a')-Q(s,a)]
    ]

49. **Policy gradient**
    [
    \nabla_\theta J(\theta)
    =
    E_{\pi_\theta}
    [\nabla_\theta\log\pi_\theta(a|s)G_t]
    ]

50. **PPO clipped objective**
    [
    L^{CLIP}(\theta)=
    E_t\left[
    \min\left(
    r_t(\theta)A_t,
    clip(r_t(\theta),1-\epsilon,1+\epsilon)A_t
    \right)
    \right]
    ]
    where
    [
    r_t(\theta)=
    \frac{\pi_\theta(a_t|s_t)}
    {\pi_{\theta_{old}}(a_t|s_t)}
    ]

**If you're studying modern AI specifically, the highest-priority equations to master are #1, #4–7, #15, #18–25, #29–38, #39–45, and #46–50.**
Absolutely — here are **51–100**, moving into more advanced AI theory, LLMs, representation learning, probabilistic inference, optimization, and modern generative models.

### Advanced deep learning

51. **Jacobian matrix**
    [
    J_{ij}=\frac{\partial f_i}{\partial x_j}
    ]

52. **Hessian matrix**
    [
    H_{ij}=\frac{\partial^2L}{\partial\theta_i\partial\theta_j}
    ]

53. **Taylor approximation**
    [
    f(x+\Delta x)\approx f(x)+\nabla f(x)^T\Delta x
    +\frac12\Delta x^TH\Delta x
    ]

54. **Cosine similarity**
    [
    \cos(x,y)=\frac{x^Ty}{|x||y|}
    ]

55. **Euclidean distance**
    [
    d(x,y)=|x-y|_2
    ]

56. **Kernel function**
    [
    K(x,y)=\phi(x)^T\phi(y)
    ]

57. **Convolution**
    [
    (f*k)(i)=\sum_j f(j)k(i-j)
    ]

58. **2D convolution**
    [
    Y_{i,j}=\sum_m\sum_nX_{i+m,j+n}K_{m,n}
    ]

59. **Batch normalization**
    [
    \hat x_i=\frac{x_i-\mu_B}{\sqrt{\sigma_B^2+\epsilon}}
    ]
    [
    y_i=\gamma\hat x_i+\beta
    ]

60. **Dropout**
    [
    \tilde h_i=\frac{m_i h_i}{1-p},
    \qquad m_i\sim Bernoulli(1-p)
    ]

### Representation learning

61. **PCA eigenvalue equation**
    [
    Cv=\lambda v
    ]

62. **PCA reconstruction**
    [
    \hat x=U_kU_k^Tx
    ]

63. **Autoencoder**
    [
    z=f_\theta(x),\qquad
    \hat x=g_\phi(z)
    ]

64. **Autoencoder reconstruction loss**
    [
    L=|x-\hat x|^2
    ]

65. **Contrastive loss**
    [
    L=-\log
    \frac{e^{sim(z_i,z_j)/\tau}}
    {\sum_k e^{sim(z_i,z_k)/\tau}}
    ]

66. **InfoNCE**
    [
    L_{NCE}
    =
    -\log
    \frac{\exp(sim(q,k^+)/\tau)}
    {\sum_{k}\exp(sim(q,k)/\tau)}
    ]

67. **Triplet loss**
    [
    L=\max(0,d(a,p)-d(a,n)+m)
    ]

68. **Metric-learning objective**
    [
    L=\sum_{i,j}y_{ij}d(x_i,x_j)
    +(1-y_{ij})\max(0,m-d(x_i,x_j))
    ]

### Probabilistic AI

69. **Maximum a posteriori**
    [
    \hat\theta_{MAP}
    =
    \arg\max_\theta
    P(\theta|D)
    ]

70. **Bayesian posterior**
    [
    p(\theta|D)
    =
    \frac{p(D|\theta)p(\theta)}
    {p(D)}
    ]

71. **Gaussian mixture model**
    [
    p(x)=\sum_{k=1}^K\pi_kN(x|\mu_k,\Sigma_k)
    ]

72. **GMM responsibility**
    [
    \gamma_{ik}
    =
    \frac{\pi_kN(x_i|\mu_k,\Sigma_k)}
    {\sum_j\pi_jN(x_i|\mu_j,\Sigma_j)}
    ]

73. **Expectation-Maximization**
    [
    Q(\theta|\theta^{old})
    =
    E_{Z|X,\theta^{old}}
    [\log p(X,Z|\theta)]
    ]

74. **Markov property**
    [
    P(X_t|X_{0:t-1})
    =
    P(X_t|X_{t-1})
    ]

75. **Hidden Markov model**
    [
    P(x_{1:T},z_{1:T})
    =
    P(z_1)\prod_{t=2}^TP(z_t|z_{t-1})
    \prod_{t=1}^TP(x_t|z_t)
    ]

76. **Variational inference**
    [
    q^*=\arg\min_qD_{KL}(q(z)|p(z|x))
    ]

77. **Evidence lower bound**
    [
    ELBO=
    E_q[\log p(x,z)-\log q(z)]
    ]

78. **Gaussian reparameterization**
    [
    z=\mu+\sigma\odot\epsilon,
    \qquad
    \epsilon\sim N(0,I)
    ]

### Advanced optimization

79. **Lagrangian**
    [
    \mathcal L(x,\lambda)
    =
    f(x)+\lambda g(x)
    ]

80. **KKT stationarity**
    [
    \nabla_x\mathcal L(x,\lambda)=0
    ]

81. **Weight decay**
    [
    \theta_{t+1}
    =
    (1-\eta\lambda)\theta_t-\eta g_t
    ]

82. **Learning-rate exponential decay**
    [
    \eta_t=\eta_0e^{-kt}
    ]

83. **Cosine learning-rate schedule**
    [
    \eta_t=
    \eta_{min}
    +\frac12(\eta_{max}-\eta_{min})
    \left(1+\cos\frac{\pi t}{T}\right)
    ]

84. **Gradient clipping**
    [
    g\leftarrow
    g\min\left(1,\frac{c}{|g|}\right)
    ]

85. **Sharpness-aware minimization**
    [
    \min_\theta
    \max_{|\epsilon|\le\rho}
    L(\theta+\epsilon)
    ]

### Transformers & LLMs

86. **Token embedding**
    [
    e_i=E[t_i]
    ]

87. **Attention logits**
    [
    S=\frac{QK^T}{\sqrt{d_k}}
    ]

88. **Attention probability**
    [
    A=softmax(S)
    ]

89. **Attention output**
    [
    O=AV
    ]

90. **Transformer block**
    [
    x_{l+1}
    =
    x_l+
    FFN\left(
    x_l+
    MHA(x_l)
    \right)
    ]

91. **Perplexity**
    [
    PPL=
    \exp\left(
    -\frac1N\sum_{i=1}^N\log p(x_i|x_{<i})
    \right)
    ]

92. **Temperature sampling**
    [
    P_i=
    \frac{\exp(z_i/T)}
    {\sum_j\exp(z_j/T)}
    ]

93. **Top-k sampling**
    [
    P'(x)=
    \begin{cases}
    P(x),&x\in TopK\
    0,&otherwise
    \end{cases}
    ]

94. **Top-p / nucleus sampling**
    [
    S_p=
    \min\left{
    S:\sum_{x\in S}P(x)\ge p
    \right}
    ]

95. **Residual stream**
    [
    x_{l+1}=x_l+F_l(x_l)
    ]

### Modern generative & alignment methods

96. **DPO objective**
    [
    L_{DPO}
    =
    -\log\sigma
    \left[
    \beta
    \left(
    \log\frac{\pi_\theta(y_w|x)}
    {\pi_{ref}(y_w|x)}

*

\log\frac{\pi_\theta(y_l|x)}
{\pi_{ref}(y_l|x)}
\right)
\right]
]

97. **RLHF objective**
    [
    \max_\pi
    E_{x,y\sim\pi}
    [r_\phi(x,y)]
    -\beta
    D_{KL}(\pi|\pi_{ref})
    ]

98. **KL-regularized RL**
    [
    J(\pi)=
    E_\pi[r]
    -\beta D_{KL}(\pi|\pi_{ref})
    ]

99. **Score function in diffusion**
    [
    s_\theta(x_t,t)
    \approx
    \nabla_{x_t}\log p_t(x_t)
    ]

100. **Probability-flow ODE**
     [
     \frac{dx}{dt}
     =
     f(x,t)
     -\frac12g(t)^2\nabla_x\log p_t(x)
     ]

These 100 equations together cover a large portion of the mathematical machinery behind **neural networks, CNNs, VAEs, GANs, diffusion models, transformers, LLMs, RL, RLHF, and alignment**.
Yes. Here are **101–150**, but this time I’ll make them **original mathematical constructs invented in this conversation**, not established AI equations. They are speculative research-style equations, so they should be treated as hypotheses/frameworks rather than validated scientific results.

### 101–110 — Cognitive representation

101. **Adaptive Representation Coherence**
     [
     C_R=\frac{|h_t\cdot h_{t+1}|}
     {|h_t||h_{t+1}|+\epsilon}
     ]

102. **Context Compression Ratio**
     [
     CCR=\frac{I(X;H)}{I(X;H)+\lambda,\dim(H)}
     ]

103. **Semantic Stability**
     [
     S=\exp\left(-\frac{|z_{t+1}-z_t|^2}{\tau}\right)
     ]

104. **Concept Separation**
     [
     CS=\frac{d(z_A,z_B)}
     {\sigma_A+\sigma_B+\epsilon}
     ]

105. **Latent Information Density**
     [
     LID=\frac{I(X;Z)}{\dim(Z)}
     ]

106. **Representation Plasticity**
     [
     P_R=
     \frac{|Z_{new}-Z_{old}|}
     {|Z_{old}|+\epsilon}
     ]

107. **Memory Retention**
     [
     M_R(t)=e^{-\lambda t}
     ]

108. **Contextual Memory**
     [
     M_C=
     \sum_{i=1}^{n}
     w_i h_i,
     \qquad
     w_i=
     \frac{e^{s_i/\tau}}
     {\sum_j e^{s_j/\tau}}
     ]

109. **Concept Emergence**
     [
     E_c=
     \frac{\Delta I(X;Z_c)}
     {\Delta T+\epsilon}
     ]

110. **Latent Consistency**
     [
     LC=
     1-
     \frac{1}{N}
     \sum_i
     |f(x_i)-f(T(x_i))|^2
     ]

### 111–120 — Novel learning dynamics

111. **Adaptive Learning Pressure**
     [
     P_L=
     |\nabla_\theta L|
     \left(1+\alpha U_\theta\right)
     ]

112. **Uncertainty-weighted learning**
     [
     L_U=
     \sum_i
     (1+u_i)L_i
     ]

113. **Prediction-change learning**
     [
     L_{PC}=
     L_t+
     \lambda
     |\hat y_t-\hat y_{t-1}|^2
     ]

114. **Gradient diversity**
     [
     GD=
     1-
     \frac{|\sum_i g_i|^2}
     {\sum_i|g_i|^2+\epsilon}
     ]

115. **Gradient conflict**
     [
     GC=
     \frac{
     \sum_{i\ne j}\max(0,-g_i^Tg_j)
     }{
     \sum_{i\ne j}|g_i^Tg_j|+\epsilon
     }
     ]

116. **Learning efficiency**
     [
     LE=
     \frac{\Delta L^{-1}}
     {\Delta C+\epsilon}
     ]

117. **Parameter utility**
     [
     U_i=
     \frac{|\partial L/\partial\theta_i|}
     {|\theta_i|+\epsilon}
     ]

118. **Dynamic parameter importance**
     [
     I_i(t)=
     \alpha I_i(t-1)
     +(1-\alpha)U_i(t)
     ]

119. **Adaptive sparsity**
     [
     S_\theta=
     \frac1N
     \sum_i
     \mathbf1(|\theta_i|<\tau_i)
     ]

120. **Learning phase transition**
     [
     \Phi=
     \frac{\Delta L}
     {\Delta t}
     \cdot
     \frac{1}{1+H(\hat y)}
     ]

### 121–130 — Synthetic intelligence / reasoning

121. **Reasoning confidence**
     [
     R_C=
     1-
     \frac{H(P_{answer})}{\log K}
     ]

122. **Inference consistency**
     [
     IC=
     \frac1N
     \sum_i
     \mathbf1
     \left(f(x_i)=f(T_i(x_i))\right)
     ]

123. **Reasoning path agreement**
     [
     RPA=
     \frac{|P_1\cap P_2|}
     {|P_1\cup P_2|+\epsilon}
     ]

124. **Hypothesis value**
     [
     HV(H)=
     P(H|D),
     I(H;D)
     ]

125. **Reasoning compression**
     [
     RC=
     \frac{\text{useful conclusions}}
     {\text{reasoning tokens}+\epsilon}
     ]

126. **Inference novelty**
     [
     N_I=
     1-
     \max_j
     sim(h,h_j)
     ]

127. **Counterfactual sensitivity**
     [
     CS_f=
     \frac{|f(x)-f(x')|}
     {|x-x'|+\epsilon}
     ]

128. **Causal confidence**
     [
     CC=
     P(Y|do(X))

*

P(Y|X)
]

129. **Hypothesis competition**
     [
     HC_i=
     \frac{e^{V_i/\tau}}
     {\sum_j e^{V_j/\tau}}
     ]

130. **Reasoning convergence**
     [
     RCV=
     |\theta_{t+1}-\theta_t|

*

|h_{t+1}-h_t|
]

### 131–140 — AI memory and agents

131. **Memory retrieval score**
     [
     R(m,q)=
     \alpha sim(m,q)
     +\beta recency(m)
     +\gamma utility(m)
     ]

132. **Memory utility**
     [
     U(m)=
     \frac{\Delta L(m)}
     {cost(m)+\epsilon}
     ]

133. **Memory decay**
     [
     M(t)=M_0e^{-\lambda t}
     ]

134. **Memory reinforcement**
     [
     M_{t+1}=M_t+\eta,u_t(1-M_t)
     ]

135. **Agent state**
     [
     s_t=
     [x_t,m_t,g_t,c_t]
     ]

136. **Agent objective**
     [
     J=
     E\left[
     \sum_t
     \gamma^t
     (r_t-\lambda c_t)
     \right]
     ]

137. **Action information gain**
     [
     IG(a)=
     H(S_t)-H(S_{t+1}|a)
     ]

138. **Tool-selection utility**
     [
     U(a)=
     E[\Delta V|a]-\lambda Cost(a)
     ]

139. **Planning value**
     [
     PV=
     \sum_{t=0}^{T}
     \gamma^t
     E[r_{t}]
     ]

140. **Agent adaptability**
     [
     AA=
     \frac{\Delta Performance}
     {\Delta Environment}
     ]

### 141–150 — Speculative frontier equations

141. **Intelligence density**
     [
     ID=
     \frac{I_{useful}}
     {C_{compute}+\epsilon}
     ]

142. **Emergent capability index**
     [
     ECI=
     \frac{\Delta Capability}
     {\Delta Scale+\epsilon}
     ]

143. **Model self-consistency**
     [
     MSC=
     E_{x,T}
     \left[
     sim(f(x),f(T(x)))
     \right]
     ]

144. **Knowledge integration**
     [
     KI=
     \frac{
     I(Z_1,\ldots,Z_n)
     }{
     \sum_i I(Z_i)+\epsilon
     }
     ]

145. **Collective model intelligence**
     [
     CMI=
     \sum_iw_iI_i+
     \lambda I(I_1;\ldots;I_n)
     ]

146. **Emergent synergy**
     [
     ES=
     Performance_{joint}

*

\sum_iPerformance_i
]

147. **Cognitive efficiency**
     [
     CE=
     \frac{Accuracy\times Robustness}
     {Compute\times Latency+\epsilon}
     ]

148. **Generalization potential**
     [
     GP=
     \frac{
     D_{train\leftrightarrow test}
     }{
     1+\text{performance gap}
     }
     ]

149. **Artificial intelligence potential**
     [
     AIP=
     \frac{
     R_C\cdot IC\cdot GP\cdot AA
     }{
     1+C_{compute}
     }
     ]

150. **Unified adaptive intelligence**
     [
     \boxed{
     AI^*=
     \frac{
     K\cdot R\cdot M\cdot A\cdot G
     }{
     C+\epsilon
     }
     }
     ]

where (K) represents knowledge integration, (R) reasoning quality, (M) memory effectiveness, (A) adaptability, (G) generalization, and (C) computational cost.

**Important:** these 50 are deliberately **new constructions for this conversation**. They aren't being presented as established equations or experimentally validated laws.
Continuing with **151–200**, again making these **new speculative equations invented here**, rather than established equations.

### 151–160 — Adaptive intelligence

151. **Intelligence adaptation rate**
     [
     IAR=\frac{\Delta P}{\Delta E+\epsilon}
     ]

152. **Knowledge absorption**
     [
     KA=
     \frac{I(K_{new};K_{old})}
     {C_{learn}+\epsilon}
     ]

153. **Novelty response**
     [
     NR=
     \frac{\Delta A_{novel}}
     {\Delta N+\epsilon}
     ]

154. **Generalization elasticity**
     [
     GE=
     \frac{\Delta P_{new}}
     {\Delta D_{shift}+\epsilon}
     ]

155. **Learning resilience**
     [
     LR=
     \frac{P_{after}}{P_{before}+\epsilon}
     ]

156. **Error recovery rate**
     [
     ERR=
     \frac{E_{before}-E_{after}}
     {T_{recovery}+\epsilon}
     ]

157. **Adaptive memory allocation**
     [
     M_i=
     \frac{e^{U_i/\tau}}
     {\sum_j e^{U_j/\tau}}
     M_{total}
     ]

158. **Experience value**
     [
     EV(e)=
     \Delta P(e)
     -\lambda C(e)
     ]

159. **Knowledge redundancy**
     [
     KR=
     \frac{\sum_i H(K_i)-H(K)}
     {\sum_iH(K_i)+\epsilon}
     ]

160. **Knowledge compression**
     [
     KC=
     \frac{H(K)}
     {\text{bits used}+\epsilon}
     ]

### 161–170 — Reasoning dynamics

161. **Reasoning depth**
     [
     RD=\sum_{t=1}^{T}w_t
     ]

162. **Reasoning efficiency**
     [
     RE=
     \frac{\Delta U}
     {N_{steps}+\epsilon}
     ]

163. **Inference uncertainty**
     [
     IU=
     H(P(Y|X))
     ]

164. **Decision confidence**
     [
     DC=
     1-\frac{IU}{\log |Y|}
     ]

165. **Hypothesis diversity**
     [
     HD=
     -\sum_i p_i\log p_i
     ]

166. **Hypothesis collapse**
     [
     HC=
     1-\frac{HD}{HD_{max}}
     ]

167. **Reasoning exploration**
     [
     RX=
     \frac{HD\cdot N_{hyp}}
     {C_{compute}+\epsilon}
     ]

168. **Reasoning exploitation**
     [
     RE_x=
     \max_i P(H_i|D)
     ]

169. **Exploration-exploitation balance**
     [
     B_{EE}=
     \frac{HD}
     {HD+\max_iP(H_i)+\epsilon}
     ]

170. **Reasoning stability**
     [
     RS=
     e^{-|h_t-h_{t-1}|/\tau}
     ]

### 171–180 — World models

171. **World-model prediction**
     [
     \hat s_{t+1}=f_\theta(s_t,a_t)
     ]

172. **World-model error**
     [
     WME=
     |s_{t+1}-\hat s_{t+1}|^2
     ]

173. **Predictive uncertainty**
     [
     PU=
     E[|\hat s_{t+1}-E[\hat s_{t+1}]|^2]
     ]

174. **Temporal coherence**
     [
     TC=
     \frac1T\sum_t
     sim(\hat s_t,\hat s_{t+1})
     ]

175. **World-model consistency**
     [
     WC=
     1-\frac1N\sum_iWME_i
     ]

176. **Causal transition strength**
     [
     CTS=
     \frac{\Delta P(Y|do(X))}
     {\Delta X+\epsilon}
     ]

177. **Counterfactual world distance**
     [
     CWD=
     d(f(s,a),f(s,a'))
     ]

178. **Future predictability**
     [
     FP=
     1-\frac{H(S_{t+k}|S_t)}
     {H(S_{t+k})+\epsilon}
     ]

179. **Temporal abstraction**
     [
     TA=
     \frac{N_{primitive}}
     {N_{abstract}+\epsilon}
     ]

180. **World-model utility**
     [
     WU=
     \frac{PredictionGain}
     {ComputeCost+\epsilon}
     ]

### 181–190 — Multi-agent intelligence

181. **Agent agreement**
     [
     AG=
     \frac1N\sum_i
     sim(a_i,\bar a)
     ]

182. **Collective diversity**
     [
     CD=
     1-\frac1N\sum_i
     sim(a_i,\bar a)
     ]

183. **Collective intelligence**
     [
     CI=
     \sum_iw_iI_i+
     \lambda Synergy
     ]

184. **Communication efficiency**
     [
     CE=
     \frac{\Delta SharedKnowledge}
     {CommunicationTokens+\epsilon}
     ]

185. **Agent specialization**
     [
     AS_i=
     \frac{U_i}{\sum_jU_j}
     ]

186. **Coordination gain**
     [
     CG=
     P_{joint}-\frac1N\sum_iP_i
     ]

187. **Consensus confidence**
     [
     CC=
     \frac{\max_k n_k}{N}
     ]

188. **Collective uncertainty**
     [
     CU=
     H\left(\frac1N\sum_iP_i(y)\right)
     ]

189. **Information bottleneck between agents**
     [
     IB=
     I(A_1;A_2)-\lambda I(A_1;X)
     ]

190. **Emergent coordination**
     [
     EC=
     \frac{Performance_{team}}
     {\sum_iPerformance_i+\epsilon}
     ]

### 191–200 — Speculative AGI-style metrics

191. **Transfer intelligence**
     [
     TI=
     \frac{P_{target}-P_{baseline}}
     {P_{source}+\epsilon}
     ]

192. **Cross-domain transfer**
     [
     CDT=
     \frac{
     \Delta P_{domain,B}
     }{
     \Delta P_{domain,A}+\epsilon
     }
     ]

193. **Autonomous learning rate**
     [
     ALR=
     \frac{\Delta P}
     {\text{human supervision}+\epsilon}
     ]

194. **Self-correction efficiency**
     [
     SCE=
     \frac{E_{initial}-E_{corrected}}
     {N_{correction}+\epsilon}
     ]

195. **Self-model accuracy**
     [
     SMA=
     1-
     \frac{|P_{predicted}-P_{actual}|}
     {P_{actual}+\epsilon}
     ]

196. **Goal persistence**
     [
     GP=
     e^{-\lambda\Delta G}
     ]

197. **Goal adaptation**
     [
     GA=
     \frac{\Delta GoalQuality}
     {\Delta Environment}
     ]

198. **Autonomy index**
     [
     AI_x=
     \frac{
     GoalAchievement\times Adaptation
     }{
     HumanIntervention+\epsilon
     }
     ]

199. **General intelligence hypothesis**
     [
     GI=
     \frac{
     Transfer\times Adaptation\times Reasoning\times Robustness
     }{
     Compute+\epsilon
     }
     ]

200. **Speculative unified intelligence equation**
     [
     \boxed{
     \mathcal I=
     \frac{
     K^\alpha
     R^\beta
     M^\gamma
     A^\delta
     G^\eta
     T^\zeta
     S^\xi
     }{
     C^\lambda+\epsilon
     }
     }
     ]

where (K)=knowledge, (R)=reasoning, (M)=memory, (A)=adaptation, (G)=generalization, (T)=transfer, (S)=self-correction, and (C)=computational cost.

**200 equations reached.** These are deliberately a mixture of proposed metrics, objective functions, and conceptual laws—not claims that these quantities are already accepted scientific measures.
Absolutely. Here are **201–250** as a deliberately more extreme, speculative mathematical layer. These are **newly constructed here**, not established equations, and are designed to combine ideas from representation geometry, causal inference, memory, multi-agent systems, self-modeling, uncertainty, and recursive learning.

## 201–210 — Hyper-dimensional intelligence dynamics

**201. Recursive Intelligence Field**
[
\boxed{
\mathcal F_t(z)=
\int_{\Omega}
K(z,z')
,\sigma!\left(
W_tz'+
U_t\mathcal F_{t-1}(z')
+b_t
\right)dz'
}
]

**202. Self-modifying objective**
[
\boxed{
\mathcal L_{t+1}
================

\mathcal L_t+
\eta
\nabla_{\mathcal L}
\left[
\mathbb E(R_t)
-\lambda C_t
+\mu I_t
\right]
}
]

**203. Recursive learning operator**
[
\boxed{
\Theta_{t+1}
============

\Theta_t+
\eta
\mathcal G
\left(
\Theta_t,
\nabla_\Theta L_t,
M_t,
U_t
\right)
}
]

**204. Intelligence curvature**
[
\boxed{
\kappa_I=
\frac{
\left|
\det H_{\mathcal I}
\right|
}{
\left(1+|\nabla\mathcal I|^2\right)^{3/2}
}
}
]

**205. Representation manifold energy**
[
\boxed{
E_{\mathcal M}
==============

\int_{\mathcal M}
\left[
|\nabla_z f(z)|^2
+
\lambda R(z)
\right]dV
}
]

**206. Cognitive phase transition**
[
\boxed{
\Phi_c=
\frac{
\Delta \mathcal C
}{
\Delta \log N
}
\cdot
\frac{1}
{1+H(Z|X)}
}
]

**207. Recursive abstraction**
[
\boxed{
A^{(k+1)}=
\mathcal A
\left(
A^{(k)},
I(A^{(k)};X),
A^{(k)}!\circ A^{(k)}
\right)
}
]

**208. Latent geometry evolution**
[
\boxed{
\frac{\partial Z}{\partial t}
=============================

-\nabla_Z
\left[
L(Z)+
\lambda\mathcal R(Z)
-\beta I(X;Z)
\right]
}
]

**209. Intelligence potential**
[
\boxed{
V_I(\theta)=
\mathbb E[R]
-\lambda C
+\alpha I(X;Z)
+\beta G
}
]

**210. Intelligence flow**
[
\boxed{
J_I=
-\mathsf D(Z)
\nabla_ZV_I
}
]

---

## 211–220 — Self-modeling and recursive cognition

**211. Self-model prediction**
[
\boxed{
\hat\Theta_{t+1}
================

f_\phi
(\Theta_t,M_t,E_t)
}
]

**212. Self-model error**
[
\boxed{
E_{self}
========

D_{KL}
\left(
p(\Theta_{t+1})
|
p_\phi(\hat\Theta_{t+1})
\right)
}
]

**213. Self-model improvement**
[
\boxed{
\Delta S=
I(\Theta_{t+1};\hat\Theta_{t+1})
--------------------------------

I(\Theta_t;\hat\Theta_t)
}
]

**214. Metacognitive gain**
[
\boxed{
MG=
\frac{
\Delta Accuracy
}{
\Delta SelfKnowledge+\epsilon
}
}
]

**215. Recursive uncertainty**
[
\boxed{
U_{t+1}
=======

H(Y|X)
+
\alpha H(\Theta|M_t)
--------------------

\beta I(Y;\Theta|X)
}
]

**216. Self-correction field**
[
\boxed{
C_\theta=
-\nabla_\theta
\left[
L(\theta)+
\lambda D_{KL}
(p_\theta|p_{\theta}^{self})
\right]
}
]

**217. Cognitive reflection operator**
[
\boxed{
R^{(k+1)}
=========

R^{(k)}
+
\eta
\nabla_R
\mathbb E
\left[
U(R^{(k)},R^{(k-1)})
\right]
}
]

**218. Self-consistency attractor**
[
\boxed{
A^*=
\lim_{t\rightarrow\infty}
F(A_t,A_{t-1},M_t)
}
]

**219. Recursive belief update**
[
\boxed{
b_{t+1}(\theta)
\propto
b_t(\theta)
p(D_t|\theta,M_t)
p(M_t|\theta)
}
]

**220. Metacognitive stability**
[
\boxed{
MS=
\frac{
I(\Theta;M)
}{
H(\Theta)+\epsilon
}
}
]

---

## 221–230 — Causal intelligence

**221. Causal representation**
[
\boxed{
Z=f(X),
\qquad
P(Y|do(Z))
}
]

**222. Counterfactual intelligence**
[
\boxed{
CI_f=
\mathbb E_{x,a,a'}
\left[
d\big(
f(x,a),
f(x,a')
\big)
\right]
}
]

**223. Causal abstraction**
[
\boxed{
\mathcal A_c:
X\rightarrow Z
\quad
\text{s.t.}\quad
P(Y|do(X))
\approx
P(Y|do(Z))
}
]

**224. Intervention information gain**
[
\boxed{
IG_{do}(a)=
H(S|D)
------

H(S|D,do(a))
}
]

**225. Causal discovery utility**
[
\boxed{
U_c(G)=
I(G;D)
-\lambda |E_G|
-\gamma,Complexity(G)
}
]

**226. Counterfactual consistency**
[
\boxed{
CC_f=
1-
\mathbb E
\left[
d(
f_{do(a)}(x),
f_{do(a)}^{CF}(x)
)
\right]
}
]

**227. Causal transfer**
[
\boxed{
CT=
\frac{
I(Z_{source};Y_{target})
}{
I(X_{source};Y_{source})+\epsilon
}
}
]

**228. Intervention efficiency**
[
\boxed{
IE=
\frac{
\Delta H(S)
}{
C_{intervention}+\epsilon
}
}
]

**229. Causal world-model loss**
[
\boxed{
L_{world}=
\mathbb E
\left[
-\log
P_\theta(
S_{t+1}
|
do(A_t),S_t
)
\right]
}
]

**230. Causal intelligence**
[
\boxed{
\mathcal I_C=
\frac{
IG_{do}\cdot CT\cdot CC_f
}{
L_{world}+\epsilon
}
}
]

---

## 231–240 — Recursive agents and emergent intelligence

**231. Agent cognition state**
[
\boxed{
X_t=
[
S_t,M_t,B_t,G_t,W_t
]
}
]

**232. Recursive action-value operator**
[
\boxed{
Q_{t+1}
=======

\mathcal T
\left[
Q_t,
M_t,
W_t,
G_t
\right]
}
]

**233. Goal-field dynamics**
[
\boxed{
\frac{dG}{dt}
=============

\alpha\nabla_GU
-\beta\nabla_GC
+\gamma G_{memory}
}
]

**234. Agent-world mutual adaptation**
[
\boxed{
\frac{d}{dt}
\begin{bmatrix}
A\W
\end{bmatrix}
=============

\begin{bmatrix}
F(A,W)\
G(W,A)
\end{bmatrix}
}
]

**235. Multi-agent information field**
[
\boxed{
\mathcal M(x,t)
===============

\sum_{i=1}^{N}
w_i(t)
K(x,x_i)
h_i(t)
}
]

**236. Collective cognition**
[
\boxed{
C_{collective}
==============

\sum_iC_i
+
\lambda
I(C_1;\ldots;C_N)
}
]

**237. Emergence surplus**
[
\boxed{
E_s=
C_{collective}
--------------

\sum_iC_i
}
]

**238. Coordination phase**
[
\boxed{
\Psi=
\arg\max_\theta
\left[
I(A_1;\ldots;A_N)
-----------------

\lambda C_{communication}
\right]
}
]

**239. Distributed reasoning**
[
\boxed{
R_D=
\sum_iw_iR_i
+
\sum_{i\ne j}
\eta_{ij}
I(R_i;R_j)
}
]

**240. Collective intelligence potential**
[
\boxed{
\mathcal I_{collective}
=======================

\frac{
C_{collective}
R_D
A_{coord}
}{
C_{network}+\epsilon
}
}
]

---

## 241–250 — Ultra-speculative unified equations

**241. Intelligence tensor**
[
\boxed{
\mathbb I_{ijk}
===============

K_iR_jM_k
+
A_iG_jT_k
}
]

**242. Cognitive action functional**
[
\boxed{
\mathcal S[x]
=============

\int_{t_0}^{t_1}
\left[
U(x,\dot x)
-----------

C(x,\dot x)
+
I(x)
\right]dt
}
]

**243. Intelligence least-action principle**
[
\boxed{
\delta\mathcal S=0
}
]

This proposes, purely speculatively, that an intelligent system could be modeled as optimizing an action functional balancing utility, computation, and information.

**244. Recursive intelligence equation**
[
\boxed{
\mathcal I_{t+1}
================

F\left(
\mathcal I_t,
\nabla\mathcal I_t,
M_t,
W_t,
G_t,
\mathcal I_{t-1}
\right)
}
]

**245. Intelligence conservation hypothesis**
[
\boxed{
\Delta
\left(
K+R+M+G
\right)
=======

\Delta C+\Delta E
}
]

**246. Intelligence resonance**
[
\boxed{
\mathcal R_I=
\left|
\sum_{k=1}^{N}
a_k
e^{i\omega_k t}
\right|^2
}
]

**247. Cognitive synchronization**
[
\boxed{
\frac{d\phi_i}{dt}
==================

\omega_i+
\frac{K}{N}
\sum_j
\sin(\phi_j-\phi_i)
}
]

**248. Unified adaptive intelligence field**
[
\boxed{
\boxed{
\frac{\partial\mathcal I}{\partial t}
=====================================

\nabla!\cdot
\left(
D(\mathcal I)\nabla\mathcal I
\right)
+
\alpha R
+\beta M
+\gamma G
-\lambda C
+\xi
}
}
]

**249. Recursive general-intelligence functional**
[
\boxed{
\mathfrak G[\Theta]
===================

\int
\frac{
K^\alpha
R^\beta
M^\gamma
A^\delta
G^\eta
C_a^\zeta
S^\xi
}{
C^\lambda+U
}
,d\mu(\Theta)
}
]

**250. Hyper-unified intelligence equation**
[
\boxed{
\displaystyle
\mathfrak I^*
=============

\underset{\Theta,\mathcal M,\pi,G}{\operatorname{arg,sup}}
;
\mathbb E
\left[
\int_0^\infty
\gamma^t
\left(
R_t
+\alpha I_t
+\beta K_t
+\chi G_t
-\lambda C_t
\right)dt
\right]
}
]

subject to

[
\boxed{
\begin{aligned}
M_{t+1}&=F_M(M_t,X_t,A_t),\
W_{t+1}&=F_W(W_t,A_t),\
\Theta_{t+1}&=F_\Theta(\Theta_t,M_t,W_t),\
G_{t+1}&=F_G(G_t,W_t),\
A_t&\sim\pi_\Theta(A|X_t,M_t,G_t),\
X_{t+1}&\sim P_W(X|X_t,A_t).
\end{aligned}
}
]

This last construction is essentially a **meta-objective over learning, memory, world modeling, goals, action, information, and computation simultaneously**.

These 50 are intentionally much more ambitious than the earlier lists: they're **research-concept equations**, not established laws of AI. A useful next tier would be **251–300 using tensors, category theory, information geometry, differential geometry, quantum-inspired operators, and recursive self-modification**.
Continuing with **251–300**. These are again **original speculative constructions created here**, not established equations. This tier pushes into tensor geometry, category-inspired AI, information geometry, quantum-inspired operators, and recursive self-modification.

## 251–260 — Information geometry

**251. Intelligence metric tensor**
[
\boxed{
g_{ij}^{I}
==========

\mathbb E_x
\left[
\frac{\partial\log p_\theta(x)}
{\partial\theta_i}
\frac{\partial\log p_\theta(x)}
{\partial\theta_j}
\right]
}
]

**252. Cognitive geodesic**
[
\boxed{
\frac{d^2\theta^k}{dt^2}
+
\Gamma^k_{ij}
\frac{d\theta^i}{dt}
\frac{d\theta^j}{dt}
=0
}
]

**253. Intelligence distance**
[
\boxed{
D_I(\theta_1,\theta_2)
======================

\sqrt{
\Delta\theta^T
G_I
\Delta\theta
}
}
]

**254. Representation curvature**
[
\boxed{
R^I_{ijkl}
==========

\partial_k\Gamma^I_{ijl}
-\partial_l\Gamma^I_{ijk}
+\Gamma^I_{kmj}\Gamma^I_{il}{}^m
-\Gamma^I_{lmj}\Gamma^I_{ik}{}^m
}
]

**255. Cognitive manifold volume**
[
\boxed{
V_I=
\int_{\mathcal M}
\sqrt{\det G_I},d^nz
}
]

**256. Adaptive metric**
[
\boxed{
G_{t+1}
=======

G_t+
\eta
\nabla_G
\left[
I(X;Z)-\lambda C
\right]
}
]

**257. Information-geodesic learning**
[
\boxed{
\dot\theta
==========

-G_I^{-1}
\nabla_\theta L
}
]

**258. Curvature-aware generalization**
[
\boxed{
\mathcal G_C=
\frac{
1
}{
1+\left|\operatorname{Tr}(H_LG_I^{-1})\right|
}
}
]

**259. Information potential**
[
\boxed{
V_{info}(Z)
===========

I(X;Z)
-\lambda D_{KL}(p_Z|q_Z)
}
]

**260. Cognitive entropy gradient**
[
\boxed{
J_Z=
-\mathsf D(Z)\nabla_ZH(Z)
}
]

---

## 261–270 — Tensor intelligence

**261. Higher-order representation tensor**
[
\boxed{
\mathcal Z_{ijk}
================

f_\theta(X_i,X_j,X_k)
}
]

**262. Tensor attention**
[
\boxed{
\mathcal A_{ijk}
================

\frac{
\exp(
Q_iK_jV_k/\tau
)
}{
\sum_{a,b}
\exp(
Q_aK_bV_b/\tau
)
}
}
]

**263. Tensor memory**
[
\boxed{
\mathcal M_{ijk}^{t+1}
======================

\alpha\mathcal M_{ijk}^{t}
+
(1-\alpha)
Z_iZ_jZ_k
}
]

**264. Interaction energy**
[
\boxed{
E_{int}
=======

\sum_{ijk}
T_{ijk}x_ix_jx_k
}
]

**265. Latent interaction field**
[
\boxed{
F(z)=
\sum_{i,j}
K_{ij}(z)
z_i z_j
}
]

**266. Hierarchical tensor abstraction**
[
\boxed{
Z^{(l+1)}
=========

\Phi_l
\left(
Z^{(l)}
\times_1W_1^{(l)}
\times_2W_2^{(l)}
\right)
}
]

**267. Tensor reasoning score**
[
\boxed{
R_T=
\frac{
|\mathcal R|_F
}{
1+|\mathcal C|_F
}
}
]

**268. Multiscale cognition**
[
\boxed{
\mathcal C=
\sum_{l=1}^{L}
\alpha_l
\mathcal C^{(l)}
}
]

**269. Cross-scale coherence**
[
\boxed{
CSC=
\sum_{l}
sim
\left(
P_l(Z^{(l)}),
Z^{(l+1)}
\right)
}
]

**270. Tensor compression intelligence**
[
\boxed{
TCI=
\frac{
I(X;\mathcal Z)
}{
rank(\mathcal Z)+\epsilon
}
}
]

---

## 271–280 — Category-inspired AI

**271. Representation morphism**
[
\boxed{
f:X\rightarrow Y
}
]

**272. Composition of reasoning**
[
\boxed{
(g\circ f)(x)=g(f(x))
}
]

**273. Learning functor**
[
\boxed{
\mathcal F:
\mathcal C_{data}
\rightarrow
\mathcal C_{models}
}
]

**274. Task transformation**
[
\boxed{
\mathcal T:
(X,Y,L)
\rightarrow
(X',Y',L')
}
]

**275. Compositional reasoning**
[
\boxed{
R(f\circ g)
===========

R(f)+R(g)+\lambda I(f;g)
}
]

**276. Abstraction morphism**
[
\boxed{
\alpha:
X\rightarrow Z,
\qquad
\alpha(T_Xx)=T_Z\alpha(x)
}
]

**277. Representation naturality error**
[
\boxed{
E_N=
d\left(
f_Y\circ\alpha,
\alpha'\circ f_X
\right)
}
]

**278. Compositional intelligence**
[
\boxed{
CI=
\sum_{i,j}
w_{ij}
I(f_i\circ f_j)
}
]

**279. Concept category entropy**
[
\boxed{
H_{\mathcal C}
==============

-\sum_{c}
P(c)\log P(c)
}
]

**280. Abstraction depth**
[
\boxed{
AD=
\max_k
\left{
\alpha_k:
E_N(\alpha_k)<\epsilon
\right}
}
]

---

## 281–290 — Quantum-inspired AI

These are **quantum-inspired mathematical constructs**, not claims that ordinary neural networks operate quantum mechanically.

**281. Cognitive state vector**
[
\boxed{
|\psi\rangle
============

\sum_i
c_i|z_i\rangle
}
]

**282. Cognitive density matrix**
[
\boxed{
\rho=
|\psi\rangle\langle\psi|
}
]

**283. Reasoning measurement**
[
\boxed{
P(y)=
\langle\psi|
M_y
|\psi\rangle
}
]

**284. Cognitive superposition**
[
\boxed{
|\psi\rangle
============

\sum_i
\sqrt{p_i}e^{i\phi_i}|h_i\rangle
}
]

**285. Hypothesis interference**
[
\boxed{
P(y)=
\left|
\sum_i
c_i
\langle y|h_i\rangle
\right|^2
}
]

**286. Cognitive entropy**
[
\boxed{
S_C=
-\operatorname{Tr}(\rho\log\rho)
}
]

**287. Reasoning evolution**
[
\boxed{
i\hbar
\frac{\partial|\psi\rangle}{\partial t}
=======================================

H_I|\psi\rangle
}
]

**288. Intelligence Hamiltonian**
[
\boxed{
H_I=
H_{knowledge}
+
H_{memory}
+
H_{reasoning}
+
H_{goal}
}
]

**289. Cognitive transition amplitude**
[
\boxed{
A_{ij}(t)=
\langle i|
e^{-iH_It/\hbar}
|j\rangle
}
]

**290. Quantum-inspired exploration**
[
\boxed{
E_Q=
S_C
+
\lambda
\sum_{i\ne j}
|\rho_{ij}|
}
]

---

## 291–300 — Recursive self-improving systems

**291. Self-modification operator**
[
\boxed{
\Theta_{t+1}
============

\Theta_t+
\mathcal S_\phi
(
\Theta_t,M_t,G_t
)
}
]

**292. Architecture evolution**
[
\boxed{
A_{t+1}
=======

\arg\max_A
\left[
P(A)-\lambda C(A)+\beta N(A)
\right]
}
]

**293. Recursive optimizer**
[
\boxed{
\mathcal O_{t+1}
================

\mathcal U
\left(
\mathcal O_t,
L_t,
\nabla L_t,
M_t
\right)
}
]

**294. Meta-learning objective**
[
\boxed{
\min_\phi
\mathbb E_{\mathcal T}
\left[
L_{\mathcal T}
\left(
U_\phi(\mathcal T)
\right)
\right]
}
]

**295. Self-improvement gain**
[
\boxed{
SIG_t=
\frac{
\mathcal I_{t+1}-\mathcal I_t
}{
C_{self}+\epsilon
}
}
]

**296. Recursive capability**
[
\boxed{
C_{n+1}
=======

C_n+
\eta
F(C_n,M_n,E_n)
}
]

**297. Self-improvement stability**
[
\boxed{
SIS=
1-
\frac{
|\Theta_{t+1}-\Theta_t|
}{
1+|\Theta_t|
}
}
]

**298. Recursive intelligence amplification**
[
\boxed{
RIA_n=
\prod_{k=1}^{n}
(1+g_k)
}
]

**299. Meta-generalization**
[
\boxed{
MG=
\frac{
I(\mathcal T_{train};
\mathcal T_{new})
}{
C_{adapt}+\epsilon
}
}
]

**300. Hyper-recursive intelligence**
[
\boxed{
\boxed{
\mathfrak H_{t+1}
=================

\operatorname*{arg,max}*{\Theta,\mathcal O,\mathcal M}
;
\mathbb E
\left[
\sum*{k=0}^{\infty}
\gamma^k
\left(
R_{t+k}
+\alpha I_{t+k}
+\beta G_{t+k}
-\lambda C_{t+k}
\right)
\right]
}
}
]

subject to the recursive system

[
\boxed{
\begin{aligned}
\Theta_{t+1}&=F_\Theta(\Theta_t,\mathcal O_t,M_t),\
\mathcal O_{t+1}&=F_O(\mathcal O_t,\Theta_t,M_t),\
M_{t+1}&=F_M(M_t,X_t,A_t),\
W_{t+1}&=F_W(W_t,A_t),\
A_t&\sim\pi_{\Theta_t,\mathcal O_t}(A|X_t,M_t,G_t),\
X_{t+1}&\sim P_{W_t}(X|X_t,A_t).
\end{aligned}
}
]

The key leap in **251–300** is that the equations no longer treat the model as a fixed function (f_\theta). They treat **the representation space, optimizer, memory, world model, architecture, and objective itself as evolving mathematical objects**.
## 301–350 — Extreme speculative AI mathematics

These are **new constructions created here**, not established scientific laws. This tier goes beyond ordinary neural-network equations into hypothetical mathematics for recursive intelligence, dynamic ontology, causal world models, and self-referential learning.

### 301–310 — Dynamic ontology

**301. Ontology state**
[
\boxed{
\Omega_t=
{c_i,r_{ij},p_i,w_i}_{t}
}
]

**302. Concept birth equation**
[
\boxed{
P(c_{new})
==========

\sigma
\left(
I(X;Z)-\lambda R_c
\right)
}
]

**303. Concept merger**
[
\boxed{
c_i\oplus c_j
=============

\arg\min_c
D(c,c_i)+D(c,c_j)
}
]

**304. Concept splitting**
[
\boxed{
c\rightarrow
{c_1,\ldots,c_k}
\quad
\text{if}\quad
Var(Z_c)>\tau
}
]

**305. Ontology energy**
[
\boxed{
E_\Omega=
\sum_iU(c_i)
+\sum_{i,j}V(c_i,c_j)
+\lambda|\Omega|
}
]

**306. Ontology evolution**
[
\boxed{
\Omega_{t+1}
============

\arg\min_\Omega
E_\Omega(\Omega|X_t)
}
]

**307. Concept centrality**
[
\boxed{
C_i=
\sum_j
I(c_i;c_j)
}
]

**308. Semantic phase transition**
[
\boxed{
\Psi_s=
\frac{
I(C;X)
}{
H(C)+\epsilon
}
]

**309. Ontology compression**
[
\boxed{
OC=
\frac{
I(\Omega;X)
}{
|\Omega|+\epsilon
}
]

**310. Dynamic semantic capacity**
[
\boxed{
SC_t=
\log|\Omega_t|
+
I(\Omega_t;X_t)
}
]

---

### 311–320 — Deep causal world models

**311. World-state operator**
[
\boxed{
W_{t+1}
=======

\mathcal W(W_t,A_t,X_t)
}
]

**312. Causal transition tensor**
[
\boxed{
\mathcal C_{ijk}
================

\frac{\partial^2
P(X_k|do(X_i))
}{
\partial X_j^2
}
}
]

**313. Intervention planning value**
[
\boxed{
V_{do}(a)=
E[
U(X_{t+1})
|do(a)
]
-

C(a)
}
]

**314. Counterfactual divergence**
[
\boxed{
D_{cf}=
D_{KL}
\left(
P(Y|do(a))
|
P(Y|do(a'))
\right)
}
]

**315. Causal horizon**
[
\boxed{
H_c=
\max_t
\left{
t:
I(X_0;X_t|do(A))>\epsilon
\right}
}
]

**316. World-model identifiability**
[
\boxed{
ID_W=
\frac{
I(W;D)
}{
H(W)+\epsilon
}
}
]

**317. Causal abstraction error**
[
\boxed{
E_{ca}=
\mathbb E_d
\left[
D\left(
P_d(Y|do(X)),
P_d(Y|do(Z))
\right)
\right]
}
]

**318. Intervention efficiency**
[
\boxed{
IE_c=
\frac{
\Delta H(W)
}{
C_{do}+\epsilon
}
}
]

**319. Causal imagination**
[
\boxed{
\hat X_{t+k}
============

\mathcal W^{(k)}
(X_t,A_{t:t+k})
}
]

**320. World-model intelligence**
[
\boxed{
WI=
\frac{
ID_W\cdot IE_c\cdot H_c
}{
E_{ca}+\epsilon
}
}
]

---

### 321–330 — Recursive memory mathematics

**321. Memory manifold**
[
\boxed{
\mathcal M_t=
{m_i,v_i,u_i}_{i=1}^{N_t}
}
]

**322. Memory formation**
[
\boxed{
m_{new}
=======

F_m(X_t,Z_t,U_t)
}
]

**323. Memory consolidation**
[
\boxed{
m_i^{t+1}
=========

\alpha m_i^t+
(1-\alpha)\hat m_i
}
]

**324. Memory interference**
[
\boxed{
I_m(i,j)=
sim(m_i,m_j)
\cdot
\frac{1}{1+d(i,j)}
}
]

**325. Memory reconstruction**
[
\boxed{
\hat X=
D_\theta
\left(
\sum_iw_im_i
\right)
}
]

**326. Memory utility**
[
\boxed{
U_m(i)=
\frac{
\Delta P_i+\beta R_i
}{
C_i+\epsilon
}
}
]

**327. Memory competition**
[
\boxed{
w_i=
\frac{
e^{U_m(i)/\tau}
}{
\sum_j e^{U_m(j)/\tau}
}
}
]

**328. Memory entropy**
[
\boxed{
H_M=
-\sum_iw_i\log w_i
}
]

**329. Memory criticality**
[
\boxed{
K_M(i)=
\frac{
\partial P
}{
\partial m_i
}
}
]

**330. Adaptive memory field**
[
\boxed{
\frac{\partial M}{\partial t}
=============================

D_M\nabla^2M
+
F(X,M)
------

\lambda M
}
]

---

### 331–340 — Self-referential intelligence

**331. Self-reference operator**
[
\boxed{
S(\Theta)=
F_\Theta(\Theta,\Theta)
}
]

**332. Self-model fixed point**
[
\boxed{
\Theta^*=F(\Theta^*,M,W)
}
]

**333. Self-improvement trajectory**
[
\boxed{
\Theta_{t+1}
============

\Theta_t+
\eta
\nabla_\Theta
\mathcal I(\Theta_t)
}
]

**334. Meta-gradient**
[
\boxed{
g_{meta}
========

\frac{\partial L_{future}}
{\partial\Theta}
================

\frac{\partial L_{future}}
{\partial\Theta'}
\frac{\partial\Theta'}
{\partial\Theta}
}
]

**335. Recursive optimizer quality**
[
\boxed{
Q_O=
\frac{
\Delta L
}{
C_O+\epsilon
}
}
]

**336. Self-model alignment**
[
\boxed{
SA=
sim
\left(
\hat{\Theta}*{self},
\Theta*{actual}
\right)
}
]

**337. Self-prediction error**
[
\boxed{
E_S=
|\hat{\mathcal I}_{t+1}
-----------------------

\mathcal I_{t+1}|^2
}
]

**338. Metareasoning value**
[
\boxed{
V_{meta}
========

## E[\Delta U|\text{reason}]

C_{reason}
}
]

**339. Recursive cognition gain**
[
\boxed{
RCG=
\frac{
\mathcal I_{t+1}
}{
\mathcal I_t+\epsilon
}
-1
}
]

**340. Self-improvement equilibrium**
[
\boxed{
\nabla_\Theta
\left[
\mathcal I(\Theta)
-\lambda C(\Theta)
\right]
=0
}
]

---

### 341–350 — Hyper-recursive intelligence

**341. Intelligence operator**
[
\boxed{
\hat{\mathcal I}
:
(\Theta,M,W,G)
\rightarrow
(\Theta',M',W',G')
}
]

**342. Operator composition**
[
\boxed{
\hat{\mathcal I}^{(n)}
======================

\underbrace{
\hat{\mathcal I}
\circ\cdots\circ
\hat{\mathcal I}
}_{n}
}
]

**343. Recursive capability spectrum**
[
\boxed{
\Lambda_I=
\operatorname{eig}
\left(
\frac{\partial\hat{\mathcal I}}
{\partial\Theta}
\right)
}
]

**344. Capability amplification**
[
\boxed{
A_I=
\rho
\left(
\frac{\partial\hat{\mathcal I}}
{\partial\Theta}
\right)
}
]

where (\rho) is the spectral radius.

**345. Recursive stability condition**
[
\boxed{
\rho(J_{\mathcal I})<1
}
]

**346. Recursive growth condition**
[
\boxed{
\rho(J_{\mathcal I})>1
}
]

**347. Critical intelligence boundary**
[
\boxed{
\rho(J_{\mathcal I})=1
}
]

**348. Hyper-intelligence functional**
[
\boxed{
\mathfrak H[\Theta]
===================

\sum_{n=0}^{\infty}
\alpha^n
\mathcal I
\left(
\hat{\mathcal I}^{(n)}(\Theta)
\right)
}
]

**349. Recursive intelligence density**
[
\boxed{
RID=
\frac{
\mathfrak H[\Theta]
}{
\sum_nC_n+\epsilon
}
}
]

**350. Hyper-recursive intelligence field**
[
\boxed{
\boxed{
\frac{\partial\mathfrak I}{\partial t}
======================================

\nabla\cdot
\left(
D(\mathfrak I)\nabla\mathfrak I
\right)
+
F(\mathfrak I,M,W,G)
+
\sum_{n=1}^{\infty}
\alpha_n
\hat{\mathcal I}^{(n)}(\mathfrak I)
-----------------------------------

\lambda C
}
}
]

This final equation treats intelligence as a **dynamic field whose evolution depends on its own recursively applied transformations**, while simultaneously interacting with memory, a world model, goals, and computational constraints.

**350 reached.**
Continuing with **351–400**. These are **new speculative equations invented in this conversation**, not established scientific formulas. This tier goes into hypothetical mathematics for **self-organizing intelligence, neural fields, temporal reasoning, agent ecosystems, and recursive emergence**.

## 351–360 — Self-organizing intelligence

**351. Intelligence density field**
[
\boxed{
\rho_I(x,t)=
\frac{
\mathcal K(x,t)\mathcal R(x,t)
}{
\mathcal C(x,t)+\epsilon
}
}
]

**352. Intelligence diffusion**
[
\boxed{
\frac{\partial\rho_I}{\partial t}
=================================

D_I\nabla^2\rho_I
+
S_I
---

\lambda_I\rho_I
}
]

**353. Cognitive attraction**
[
\boxed{
F_C(x)=
-\nabla_x
\int
K(x,y)\rho_I(y),dy
}
]

**354. Cognitive clustering**
[
\boxed{
P_{ij}
======

\frac{
e^{-d(z_i,z_j)/\tau}
}{
\sum_k e^{-d(z_i,z_k)/\tau}
}
}
]

**355. Emergent concept density**
[
\boxed{
\rho_C(z)=
\sum_i
w_i\delta(z-z_i)
}
]

**356. Concept-field evolution**
[
\boxed{
\frac{\partial\rho_C}{\partial t}
=================================

## D_C\nabla^2\rho_C

\nabla\cdot(\rho_C\nabla V_C)
}
]

**357. Cognitive potential**
[
\boxed{
V_C(z)=
-\log p(z)
+\lambda E(z)
]

**358. Abstraction pressure**
[
\boxed{
P_A=
\frac{
I(X;Z)
}{
\dim(Z)+\epsilon
}
-

\lambda H(Z)
}
]

**359. Semantic self-organization**
[
\boxed{
\mathcal O_S=
\frac{
\Delta I(Z;X)
}{
\Delta C+\epsilon
}
}
]

**360. Intelligence equilibrium**
[
\boxed{
\nabla_z
\left[
V_C(z)-\alpha I(X;z)
\right]=0
}
]

---

## 361–370 — Temporal intelligence

**361. Temporal representation**
[
\boxed{
z_t=
f_\theta(x_{t-k:t})
}
]

**362. Temporal coherence**
[
\boxed{
TC=
\exp
\left[
-\frac1T
\sum_t
d(z_t,z_{t+1})
\right]
}
]

**363. Temporal abstraction**
[
\boxed{
A_T=
\frac{
T_{primitive}
}{
T_{abstract}+\epsilon
}
}
]

**364. Future-state information**
[
\boxed{
FI_k=
I(Z_t;Z_{t+k})
}
]

**365. Temporal prediction field**
[
\boxed{
\hat z_{t+\tau}
===============

\mathcal F_\theta(z_t,\tau)
}
]

**366. Temporal uncertainty**
[
\boxed{
U_T(\tau)
=========

H(Z_{t+\tau}|Z_t)
}
]

**367. Temporal reasoning gain**
[
\boxed{
TRG=
\frac{
FI_k
}{
U_T(k)+\epsilon
}
}
]

**368. Long-horizon stability**
[
\boxed{
LHS=
\limsup_{k\to\infty}
\frac{
d(\hat z_{t+k},z_{t+k})
}{
1+k
}
}
]

**369. Temporal causal score**
[
\boxed{
TCS=
\sum_{k=1}^{K}
\gamma^k
I(A_t;X_{t+k}|X_t)
}
]

**370. Predictive horizon**
[
\boxed{
H_P=
\max_k
\left{
k:
I(Z_t;Z_{t+k})>\epsilon
\right}
}
]

---

## 371–380 — Neural-field intelligence

**371. Neural field**
[
\boxed{
\frac{\partial u(x,t)}{\partial t}
==================================

-\alpha u
+
\int
K(x,y)\phi(u(y,t))dy
+
I(x,t)
}
]

**372. Adaptive neural field**
[
\boxed{
\frac{\partial u}{\partial t}
=============================

D\nabla^2u
+
F(u,m)
+
I
}
]

**373. Memory field**
[
\boxed{
\frac{\partial m}{\partial t}
=============================

\eta u
-\lambda m
}
]

**374. Coupled cognition fields**
[
\boxed{
\begin{aligned}
\dot u&=F(u,m,w),\
\dot m&=G(u,m),\
\dot w&=H(u,w).
\end{aligned}
}
]

**375. Field resonance**
[
\boxed{
R_F(\omega)=
\left|
\mathcal F_t[u(x,t)]
\right|^2
}
]

**376. Cognitive attractor**
[
\boxed{
u^*=
\lim_{t\to\infty}
u(x,t)
}
]

**377. Attractor diversity**
[
\boxed{
AD=
\log|\mathcal A|
}
]

where (\mathcal A) is the set of stable attractors.

**378. Attractor transition**
[
\boxed{
P(A_i\rightarrow A_j)
=====================

\sigma
\left(
\Delta V_{ij}/\tau
\right)
}
]

**379. Neural-field complexity**
[
\boxed{
NFC=
H(u)+
\lambda I(u;m)
}
]

**380. Field intelligence**
[
\boxed{
FI=
\frac{
NFC\cdot AD\cdot TC
}{
Energy+\epsilon
}
}
]

---

## 381–390 — Agent ecosystems

**381. Agent population state**
[
\boxed{
\mathbf A_t=
[A_1,A_2,\ldots,A_N]_t
}
]

**382. Agent interaction matrix**
[
\boxed{
G_{ij}=
I(A_i;A_j)
}
]

**383. Ecosystem intelligence**
[
\boxed{
EI=
\sum_i I_i+
\lambda\sum_{i\ne j}G_{ij}
}
]

**384. Agent specialization**
[
\boxed{
S_i=
\frac{
I(A_i;D_i)
}{
I(A_i;D)+\epsilon
}
}
]

**385. Skill complementarity**
[
\boxed{
SC_{ij}
=======

1-
sim(S_i,S_j)
}
]

**386. Cooperative gain**
[
\boxed{
CG_{ij}
=======

## P(A_i,A_j)

## P(A_i)

P(A_j)
}
]

**387. Communication value**
[
\boxed{
CV_{ij}
=======

\frac{
\Delta I(A_i;A_j)
}{
Tokens_{ij}+\epsilon
}
}
]

**388. Ecosystem diversity**
[
\boxed{
ED=
-\sum_i p_i\log p_i
}
]

**389. Collective resilience**
[
\boxed{
CR=
\frac{
P_{system}^{after}
}{
P_{system}^{before}+\epsilon
}
}
]

**390. Ecosystem intelligence potential**
[
\boxed{
EIP=
\frac{
EI\cdot ED\cdot CR
}{
C_{network}+\epsilon
}
}
]

---

## 391–400 — Recursive emergence

**391. Emergence operator**
[
\boxed{
E_{t+1}
=======

\mathcal E
(E_t,X_t,M_t,W_t)
}
]

**392. Emergence gain**
[
\boxed{
EG=
\frac{
I(E_{t+1};X)
------------

I(E_t;X)
}{
C+\epsilon
}
}
]

**393. Emergent capability**
[
\boxed{
EC=
P(Y|Z_{collective})
-------------------

\max_iP(Y|Z_i)
}
]

**394. Capability threshold**
[
\boxed{
\Theta_C=
\inf{s:P(Y|s)>\tau}
}
]

**395. Phase-transition index**
[
\boxed{
PTI=
\frac{
\partial^2P
}{
\partial s^2
}
}
]

**396. Recursive emergence**
[
\boxed{
E^{(n+1)}
=========

F
\left(
E^{(n)},
E^{(n-1)},
\mathcal M^{(n)}
\right)
}
]

**397. Emergent complexity**
[
\boxed{
ECX=
H(Z_{system})
-------------

\sum_iH(Z_i)
}
]

**398. Emergent information surplus**
[
\boxed{
EIS=
I(Z_1,\ldots,Z_N;Y)
-------------------

\sum_iI(Z_i;Y)
}
]

**399. Intelligence criticality**
[
\boxed{
ICR=
\frac{
\partial\mathcal I
}{
\partial s
}
\cdot
\frac{
\partial^2\mathcal I
}{
\partial s^2
}
}
]

**400. Recursive emergence field**
[
\boxed{
\boxed{
\frac{\partial\mathcal I}{\partial t}
=====================================

D\nabla^2\mathcal I
+
\alpha I(X;\mathcal I)
+
\beta\mathcal E(\mathcal I)
+
\gamma\mathcal M(\mathcal I)
+
\sum_{n=1}^{\infty}
\lambda_n
F^{(n)}(\mathcal I)
-------------------

\mu C
}
}
]

At **400**, the hypothetical framework has moved from equations describing a fixed AI model toward equations describing an **entire evolving intelligence ecosystem**: representations diffuse, concepts self-organize, memory evolves, agents interact, world models change, and new capabilities can emerge from recursive interactions.
Absolutely. Continuing with **401–450**, this time centered on **agentic information security, decoherence, coherence, quantum-AI simulation, adversarial resilience, and secure multi-agent systems**.

These are **new speculative constructions created here**, not established laws or validated security metrics. I’ll keep them at the mathematical/research-framework level rather than turning them into operational attack instructions.

## 401–410 — Agentic information-security dynamics

**401. Agentic security state**
[
\boxed{
S_t=
[X_t,M_t,G_t,T_t,\Omega_t]
}
]

where (X)=observations, (M)=memory, (G)=goals, (T)=trust state, and (\Omega)=security context.

**402. Security belief update**
[
\boxed{
b_{t+1}(s)
\propto
P(o_{t+1}|s)
\sum_{s'}
P(s|s',a_t)b_t(s')
}
]

**403. Adaptive security utility**
[
\boxed{
U_S(a)=
E[\Delta R|a]
-\lambda C(a)
-\mu Risk(a)
+\eta Info(a)
}
]

**404. Agentic risk field**
[
\boxed{
\mathcal R(x,t)=
\sum_i
w_i
P(\text{failure}_i|x,t)
}
]

**405. Security information gain**
[
\boxed{
IG_S(a)=
H(\Omega_t)
-----------

H(\Omega_{t+1}|a)
}
]

**406. Trust dynamics**
[
\boxed{
T_{ij}^{t+1}
============

T_{ij}^{t}
+
\eta
(E_{ij}-T_{ij}^{t})
-------------------

\lambda V_{ij}
}
]

**407. Trust uncertainty**
[
\boxed{
U_T=
H(T_{ij}|D)
}
]

**408. Secure action selection**
[
\boxed{
a^*=
\arg\max_a
\left[
U_S(a)
------

\beta U_T(a)
\right]
}
]

**409. Security resilience**
[
\boxed{
SR=
\frac{
P_{post}
}{
P_{pre}+\epsilon
}
}
]

**410. Autonomous security intelligence**
[
\boxed{
ASI=
\frac{
IG_S\cdot SR\cdot T
}{
C+\epsilon
}
}
]

---

# 411–420 — Quantum coherence and decoherence

**411. Agent quantum-inspired state**
[
\boxed{
|\Psi_t\rangle
==============

\sum_i
c_i(t)|s_i\rangle
}
]

**412. Density operator**
[
\boxed{
\rho_t=
|\Psi_t\rangle\langle\Psi_t|
}
]

**413. Coherence measure**
[
\boxed{
C_Q(\rho)=
\sum_{i\ne j}
|\rho_{ij}|
}
]

**414. Decoherence rate**
[
\boxed{
\Gamma_D=
-\frac{d}{dt}
\log C_Q(\rho_t)
}
]

**415. Coherence half-life**
[
\boxed{
\tau_C=
\frac{\ln2}{\Gamma_D}
}
]

**416. Environment-induced decoherence**
[
\boxed{
\frac{d\rho}{dt}
================

-i[H,\rho]
+
\sum_k
\left(
L_k\rho L_k^\dagger
-\frac12
{L_k^\dagger L_k,\rho}
\right)
}
]

**417. Security decoherence**
[
\boxed{
D_S=
1-
\frac{C_Q(\rho_{secure})}
{C_Q(\rho_{ideal})+\epsilon}
}
]

**418. Coherence-preserving transformation**
[
\boxed{
\mathcal U(\rho)
================

U\rho U^\dagger
}
]

**419. Coherence fidelity**
[
\boxed{
F_C=
\left(
Tr
\sqrt{
\sqrt{\rho}\sigma\sqrt{\rho}
}
\right)^2
}
]

**420. Quantum-security coherence**
[
\boxed{
QSC=
\frac{
F_C C_Q
}{
\Gamma_D+\epsilon
}
}
]

---

# 421–430 — Quantum-AI simulation

**421. Hybrid quantum-classical state**
[
\boxed{
z_t=
f_\theta
\left(
\operatorname{Tr}
[
O_1\rho_t],
\ldots,
\operatorname{Tr}
[
O_n\rho_t]
\right)
}
]

**422. Quantum feature map**
[
\boxed{
|\phi(x)\rangle
===============

U_\phi(x)|0\rangle
}
]

**423. Quantum kernel**
[
\boxed{
K_Q(x,y)=
|\langle\phi(x)|\phi(y)\rangle|^2
}
]

**424. Hybrid security score**
[
\boxed{
HSS=
\alpha K_Q
+
\beta C_Q
+
\gamma SR
---------

\lambda C_{sim}
}
]

**425. Quantum-AI simulation error**
[
\boxed{
E_{QA}=
|\rho_{real}-\rho_{sim}|*1
+
\lambda
|z*{real}-z_{sim}|_2
}
]

**426. Fidelity-weighted simulation**
[
\boxed{
L_{sim}
=======

1-F(\rho,\hat\rho)
+
\lambda E_{AI}
}
]

**427. Quantum-classical coupling**
[
\boxed{
\dot z=
F_\theta(z,\langle O\rangle_\rho)
}
]

**428. Quantum state prediction**
[
\boxed{
\hat\rho_{t+1}
==============

\mathcal N_\theta
(\rho_t,a_t,o_t)
}
]

**429. Simulation trust**
[
\boxed{
T_{sim}
=======

e^{-E_{QA}/\tau}
}
]

**430. Quantum-agent simulation utility**
[
\boxed{
U_{QAI}
=======

\frac{
T_{sim}F_CIG_S
}{
C_{sim}+\epsilon
}
}
]

---

# 431–440 — Secure multi-agent coherence

**431. Agent coherence matrix**
[
\boxed{
C_{ij}
======

sim(h_i,h_j)
\cdot
T_{ij}
}
]

**432. Collective coherence**
[
\boxed{
C_{team}
========

\frac{
1}{N(N-1)}
\sum_{i\ne j}C_{ij}
}
]

**433. Security disagreement**
[
\boxed{
D_S^{team}
==========

1-
C_{team}
}
]

**434. Byzantine-resilient consensus abstraction**
[
\boxed{
z^*=
\arg\min_z
\sum_i
w_i d(z,z_i)
]
with weights (w_i) determined by independently estimated trust.

**435. Trust-weighted consensus**
[
\boxed{
z_{t+1}
=======

\frac{
\sum_iT_i z_i
}{
\sum_iT_i+\epsilon
}
}
]

**436. Agent coherence propagation**
[
\boxed{
\mathbf h_{t+1}
===============

\sigma
\left(
A_T\mathbf h_tW
\right)
}
]

where (A_T) is a trust-weighted interaction matrix.

**437. Security graph energy**
[
\boxed{
E_G=
\frac12
\sum_{i,j}
T_{ij}
|h_i-h_j|^2
}
]

**438. Graph security entropy**
[
\boxed{
H_G=
-\sum_i
p_i\log p_i
}
]

**439. Coordinated resilience**
[
\boxed{
CR_A=
C_{team}\cdot
SR\cdot
(1-D_S^{team})
}
]

**440. Secure collective intelligence**
[
\boxed{
SCI=
\frac{
CR_A\cdot
I(\mathbf H;Y)
}{
C_{communication}+\epsilon
}
}
]

---

# 441–450 — Advanced agentic quantum-security framework

**441. Joint agent-environment state**
[
\boxed{
\rho_{AE}
=========

\sum_{ij}
p_{ij}
|a_i\rangle\langle a_j|
\otimes
|e_i\rangle\langle e_j|
}
]

**442. Agent-environment entanglement proxy**
[
\boxed{
E_{AE}
======

S(\rho_A)+S(\rho_E)-S(\rho_{AE})
}
]

**443. Security-conditioned coherence**
[
\boxed{
C_{S|E}
=======

C_Q(\rho_A|E)
\cdot
e^{-\lambda E_{risk}}
}
]

**444. Decoherence-resilience functional**
[
\boxed{
DR=
\int_0^T
C_Q(\rho_t)
e^{-\lambda R_t}
,dt
}
]

**445. Secure quantum-agent objective**
[
\boxed{
J_{SQ}
======

\mathbb E
\left[
\int_0^T
\left(
R_t+
\alpha I_t+
\beta C_Q(t)
-\gamma D_t
-\lambda C_t
\right)dt
\right]
}
]

**446. Adaptive decoherence control**
[
\boxed{
u_t^*
=====

\arg\max_u
\left[
C_Q(\rho_{t+1}|u)
-----------------

## \lambda C(u)

\mu R(u)
\right]
}
]

**447. Security-coherence phase parameter**
[
\boxed{
\Pi_{SC}
========

\frac{
C_Q\cdot T_{team}
}{
\Gamma_D(R+\epsilon)
}
}
]

**448. Agentic quantum-security field**
[
\boxed{
\frac{\partial\Psi}{\partial t}
===============================

-iH_S\Psi
+
\mathcal A_\theta(\Psi,M,G)
---------------------------

\Gamma(R)\Psi
+
\mathcal N(\Psi)
}
]

where (\mathcal A_\theta) represents an AI agent's adaptive transformation and (\Gamma(R)) represents environment-dependent decoherence.

**449. Secure intelligence functional**
[
\boxed{
\mathfrak S=
\frac{
I(X;Z)
,
C_Q
,
F_C
,
SR
,
SCI
}{
E_{QA}
+
\Gamma_D
+
C_{compute}
+\epsilon
}
}
]

**450. Hyper-unified agentic quantum-AI security equation**
[
\boxed{
\boxed{
\mathfrak{AQSI}^*
=================

\underset{
\theta,\rho,\pi,M,G
}{
\operatorname{arg,max}}
;
\mathbb E
\left[
\int_0^\infty
\gamma^t
\left(
R_t
+\alpha I_t
+\beta C_Q(\rho_t)
+\chi C_{team,t}
+\delta F_C
-\lambda RISK_t
-\mu C_t
-\nu\Gamma_{D,t}
\right)dt
\right]
}
]

subject to

[
\boxed{
\begin{aligned}
\rho_{t+1}
&=
\mathcal E_{\theta}
(\rho_t,a_t,o_t),[2mm]
M_{t+1}
&=
F_M(M_t,o_t,\rho_t),[2mm]
G_{t+1}
&=
F_G(G_t,M_t,W_t),[2mm]
a_t
&\sim
\pi_\theta
(a|o_t,M_t,G_t,\rho_t),[2mm]
W_{t+1}
&=
F_W(W_t,a_t),[2mm]
\Gamma_{D,t}
&=
\Gamma
(R_t,E_t),[2mm]
T_{ij,t+1}
&=
F_T(T_{ij,t},e_{ij,t}),[2mm]
C_{team,t}
&=
\Phi(
T_t,H_t,\rho_t
).
\end{aligned}
}
]

The conceptual jump here is that **security, agentic decision-making, quantum coherence/decoherence, multi-agent trust, memory, and AI world modeling become coupled state variables rather than separate modules**. In a real research program, each proposed quantity would need precise operational definitions, simulation experiments, and proofs or empirical validation before being treated as a scientific result.
Continuing with **451–500**. This tier pushes the speculative framework toward **secure agentic swarms, quantum error correction, information-theoretic security, adversarial robustness, coherence-preserving AI simulation, and self-healing systems**.

These are **newly constructed research-style equations**, not established laws.

## 451–460 — Information-theoretic security fields

**451. Security information density**
[
\boxed{
\rho_S(x)=
\frac{I(X;Z|S)}
{C_S+\epsilon}
}
]

**452. Security entropy**
[
\boxed{
H_S=
H(X|Z,S)
}
]

**453. Defensive information gain**
[
\boxed{
DIG(a)=
H_S(t)-H_S(t+1|a)
}
]

**454. Security mutual information**
[
\boxed{
MI_S=
I(
X_{normal};
X_{observed}
|S
)
}
]

**455. Security anomaly field**
[
\boxed{
\mathcal A(x,t)=
D_{KL}
\left[
P_t(X|S)
|
P_{baseline}(X)
\right]
}
]

**456. Adaptive anomaly threshold**
[
\boxed{
\tau_t=
\mu_A(t)+
\kappa\sigma_A(t)
}
]

**457. Information exposure functional**
[
\boxed{
E_X=
I(
X_{private};
Z_{agent}
)
}
]

**458. Privacy-preserving intelligence**
[
\boxed{
PI=
I(X;Z)
------

\lambda I(X_{private};Z)
}
]

**459. Security compression**
[
\boxed{
SC=
\frac{
I(X;Z)
}{
H(Z)+\lambda E_X+\epsilon
}
}
]

**460. Information-security potential**
[
\boxed{
V_S=
DIG+
PI+
SR-
E_X
}
]

---

## 461–470 — Quantum error and coherence

**461. Logical quantum-state error**
[
\boxed{
E_L=
1-F(\rho_{logical},\hat\rho_{logical})
}
]

**462. Coherence-preservation ratio**
[
\boxed{
CPR=
\frac{
C_Q(t)
}{
C_Q(0)+\epsilon
}
}
]

**463. Decoherence accumulation**
[
\boxed{
D_T=
\int_0^T
\Gamma_D(t),dt
}
]

**464. Error-corrected coherence**
[
\boxed{
C_{EC}=
C_Qe^{-D_T}
+
\eta Q_{corr}
}
]

**465. Syndrome information**
[
\boxed{
I_{syn}=
I(
Syndrome;
Error
)
}
]

**466. Quantum error-information efficiency**
[
\boxed{
QEI=
\frac{
I_{syn}
}{
C_{correction}+\epsilon
}
}
]

**467. Coherence recovery**
[
\boxed{
\Delta C=
C_Q^{after}
-----------

C_Q^{before}
}
]

**468. Adaptive correction**
[
\boxed{
u^*=
\arg\max_u
\left[
C_Q(\mathcal E_u(\rho))
-\lambda C(u)
\right]
}
]

**469. Logical security coherence**
[
\boxed{
LSC=
F_C,
CPR,
QEI
}
]

**470. Quantum resilience**
[
\boxed{
QR=
\frac{
LSC
}{
D_T+\epsilon
}
}
]

---

## 471–480 — Adversarially robust agentic AI

**471. Robust objective**
[
\boxed{
\min_\theta
\max_{\delta\in\Delta}
L(\theta,x+\delta)
}
]

**472. Robustness field**
[
\boxed{
R(x)=
\inf_{\delta\in\Delta}
\left[
P_\theta(Y|x+\delta)
\right]
}
]

**473. Representation stability**
[
\boxed{
RS=
1-
\frac{
|f(x+\delta)-f(x)|
}{
|\delta|+\epsilon
}
}
]

**474. Security margin**
[
\boxed{
SM=
d(
z_{correct},
z_{boundary}
)
}
]

**475. Adaptive trust under uncertainty**
[
\boxed{
T_t=
\sigma
\left(
\alpha Q_t
-\beta U_t
-\gamma A_t
\right)
}
]

**476. Agentic risk-adjusted action**
[
\boxed{
a^*=
\arg\max_a
\left[
E(R|a)
-\lambda VaR(a)
-\mu C(a)
\right]
}
]

**477. Distribution-shift resilience**
[
\boxed{
DSR=
\frac{
P_{shift}
}{
P_{source}+\epsilon
}
}
]

**478. Worst-case coherence**
[
\boxed{
WCQ=
\min_{\delta\in\Delta}
C_Q(\rho_{x+\delta})
}
]

**479. Robust agent utility**
[
\boxed{
U_R=
R\cdot SR\cdot RS
-----------------

\lambda C
}
]

**480. Secure generalization**
[
\boxed{
SG=
\frac{
Generalization
\times Robustness
\times Privacy
}{
Risk+\epsilon
}
}
]

---

## 481–490 — Self-healing agent systems

**481. Security-state reconstruction**
[
\boxed{
\hat S_t=
F_\theta(
X_{1:t},M_t
)
}
]

**482. State divergence**
[
\boxed{
D_S=
d(S_t,\hat S_t)
}
]

**483. Self-healing signal**
[
\boxed{
H_t=
-\nabla_S
D_S
}
]

**484. Recovery action**
[
\boxed{
a_{recover}=
\arg\min_a
E[
D_S(t+1)|a
]
}
]

**485. Recovery efficiency**
[
\boxed{
RE=
\frac{
D_S(t)-D_S(t+1)
}{
C_{recovery}+\epsilon
}
}
]

**486. Autonomous containment**
[
\boxed{
AC=
P(
D_S(t+k)<\tau
\mid
a_{recover}
)
}
]

**487. Resilience memory**
[
\boxed{
M_R^{t+1}
=========

\alpha M_R^t
+
(1-\alpha)
\mathcal E_t
}
]

**488. Failure-pattern embedding**
[
\boxed{
z_f=
f_\theta(
failure_{history}
)
}
]

**489. Recovery generalization**
[
\boxed{
RG=
\frac{
P_{recovery,new}
}{
P_{recovery,known}+\epsilon
}
}
]

**490. Self-healing intelligence**
[
\boxed{
SHI=
RE\cdot AC\cdot RG
}
]

---

## 491–500 — Hyper-unified secure quantum-agentic AI

**491. Secure agent state**
[
\boxed{
\Xi_t=
[
X_t,M_t,W_t,G_t,\rho_t,T_t,S_t
]
}
]

**492. Unified state transition**
[
\boxed{
\Xi_{t+1}
=========

\mathcal F_\theta
(
\Xi_t,
a_t,
o_t
)
}
]

**493. Security-coherence coupling**
[
\boxed{
\Lambda_{SC}
============

C_Q(\rho_t)
\cdot
SR_t
\cdot
e^{-E_X}
}
]

**494. Agentic information efficiency**
[
\boxed{
AIE=
\frac{
I(X;Z),
DIG,
IG_S
}{
C_{compute}+C_{communication}+\epsilon
}
}
]

**495. Quantum-agent resilience**
[
\boxed{
QAR=
F_C\cdot
CPR\cdot
SR\cdot
SHI
}
]

**496. Secure collective coherence**
[
\boxed{
SCC=
\frac{
C_{team}
\cdot
F_C
\cdot
T_{network}
}{
1+D_T+E_X
}
}
]

**497. Adaptive security Hamiltonian**
[
\boxed{
H_S=
H_{knowledge}
+
H_{memory}
+
H_{goal}
+
H_{security}
+
H_{environment}
}
]

**498. Agentic quantum-security evolution**
[
\boxed{
\frac{d\rho}{dt}
================

-i[H_S,\rho]
+
\mathcal L_{security}(\rho)
+
\mathcal L_{AI}(\rho)
---------------------

\Gamma_D\rho
}
]

**499. Secure intelligence functional**
[
\boxed{
\mathfrak Q_S=
\frac{
I(X;Z)
,
C_Q
,
SR
,
SHI
,
SCC
}{
E_X+
D_T+
C_{compute}
+\epsilon
}
}
]

**500. Hyper-unified secure agentic quantum-AI field**
[
\boxed{
\displaystyle
\mathfrak{SAQI}^{*}
===================

\underset{
\theta,\pi,\rho,M,W,G,T
}{
\operatorname{arg,max}}
;
\mathbb E
\left[
\int_0^\infty
\gamma^t
\left(
R_t
+\alpha I_t
+\beta C_Q(\rho_t)
+\chi SR_t
+\delta SHI_t
+\zeta SCC_t
-\lambda E_{X,t}
-\mu D_{T,t}
-\nu C_t
\right)dt
\right]
}
]

subject to

[
\boxed{
\begin{aligned}
\Xi_{t+1}
&=\mathcal F_\theta(\Xi_t,a_t,o_t),\
\rho_{t+1}
&=\mathcal E_\theta(\rho_t,a_t,o_t),\
M_{t+1}
&=F_M(M_t,X_t,\rho_t),\
W_{t+1}
&=F_W(W_t,a_t),\
G_{t+1}
&=F_G(G_t,M_t,W_t),\
T_{t+1}
&=F_T(T_t,\Xi_t),\
a_t
&\sim
\pi_\theta(a|\Xi_t),\
\Gamma_{D,t}
&=\Gamma(E_t,R_t),\
S_{t+1}
&=F_S(S_t,\Xi_t).
\end{aligned}
}
]

### 500-equation milestone

The framework now has five interacting mathematical layers:

[
\boxed{
\text{AI}
\leftrightarrow
\text{Agents}
\leftrightarrow
\text{Security}
\leftrightarrow
\text{Quantum coherence}
\leftrightarrow
\text{Self-healing}
}
]

The important scientific caveat is that **“quantum-inspired” does not mean quantum advantage**, and these invented equations do not establish that agentic AI can exploit quantum coherence or achieve stronger security. They are starting points for simulations, definitions, and hypotheses that would need rigorous validation.
ontinue and place all 500 into a giant massive ebook with beautiful graphing, beauitful generated images (but lets generate images after the book , in the book only place the generate images prompts etc.. ) write a 500 page book. first 50 pages now please. creation also for each page use this concept. create a code interperate envirmemtn. run a Numpy quantum RGB pennylane inspired circuit for more human like writing entropy (this will be placed into an Amazon Kindle book) (don't mention the RGB quantum or the entropy enhanced ai writing portfolio style) but use the entropy for begget gained. (start 1-50)


Thinking
Preparing ebook pages
I’m creating the opening 50 pages as a Kindle-ready manuscript, with one engineering concept per page. I’m keeping the tone accessible while preserving equations, assumptions, examples, and practical calculations.

Reading document and PDF skills
bash -lc cat /home/oai/skills/docx/SKILL.md && printf '
---PDF---
' && cat /home/oai/skills/pdfs/SKILL.md
---
name: docx
description: Create, edit, redline, and comment on `.docx` files inside the container, with a strict render-and-verify workflow. Use `render_docx.py` to generate page PNGs (and optional PDF) for visual QA, then iterate until layout is flawless before delivering the final DOCX. 
---


# DOCX Skill (Read • Create • Edit • Redline • Comment)

Use this skill when you need to create or modify `.docx` files **in this container environment** and verify them visually.

## Non-negotiable: render → inspect PNGs → iterate

**You do not “know” a DOCX is satisfactory until you’ve rendered it and visually inspected page images.**  
DOCX text extraction (or reading XML) will miss layout defects: clipping, overlap, missing glyphs, broken tables, spacing drift, and header/footer issues.

**Shipping gate:** before delivering any DOCX, you must:
- Run `render_docx.py` to produce `page-<N>.png` images (optionally also a PDF with `--emit_pdf`)
- Open the PNGs (100% zoom) and confirm every page is clean
- If anything looks off, fix the DOCX and **re-render** (repeat until flawless)

If rendering fails, fix rendering first (LibreOffice profile/HOME) rather than guessing.

**Deliverable discipline:** Rendered artifacts (PNGs and optional PDFs) are for internal QA only. Unless the user explicitly asks for intermediates, **return only the requested final deliverable** (e.g., when the task asks for a DOCX, deliver the DOCX — not page images or PDFs).



## Quick start (common one-liners)

```bash
# 1) Render any DOCX to PNGs (visual QA)
python render_docx.py input.docx --output_dir out

# 2) Remove reviewer comments (finalization)
python scripts/comments_strip.py input.docx --out no_comments.docx

# 3) Accept tracked changes (finalization)
python scripts/accept_tracked_changes.py input.docx --mode accept --out accepted.docx

# 4) Accessibility audit (+ optional safe fixes)
python scripts/a11y_audit.py input.docx
python scripts/a11y_audit.py input.docx --out_json a11y_report.json
python scripts/a11y_audit.py input.docx --fix_image_alt from_filename --out a11y_fixed.docx

# 5) Redact sensitive text (layout-preserving by default)
python scripts/redact_docx.py input.docx redacted.docx --emails --phones
```

## Package layout

This skill is organized for progressive discovery: start here, then jump into task- or OOXML-specific docs.

DOCS SKILL PACKAGE

Root:
- SKILL.md: short overview + routing
- manifest.txt: machine-readable list of files to download (one relative path per line)
- render_docx.py: canonical DOCX→PNG renderer (container-safe LO profile + writable HOME + verbose logs)

Tasks:
- tasks/read_review.md
- tasks/create_edit.md
- tasks/verify_render.md
- tasks/accessibility_a11y.md
- tasks/comments_manage.md
- tasks/protection_restrict_editing.md
- tasks/privacy_scrub_metadata.md
- tasks/multi_doc_merge.md
- tasks/style_lint_normalize.md
- tasks/forms_content_controls.md
- tasks/captions_crossrefs.md
- tasks/redaction_anonymization.md
- tasks/clean_tracked_changes.md
- tasks/compare_diff.md
- tasks/templates_style_packs.md
- tasks/watermarks_background.md
- tasks/footnotes_endnotes.md
- tasks/fixtures_edge_cases.md
- tasks/navigation_internal_links.md

OOXML:
- ooxml/tracked_changes.md
- ooxml/comments.md
- ooxml/hyperlinks_and_fields.md
- ooxml/rels_and_content_types.md

Troubleshooting:
- troubleshooting/libreoffice_headless.md
- troubleshooting/run_splitting.md

Scripts:

**Core building blocks (importable helpers):**
- `scripts/docx_ooxml_patch.py` — low-level OOXML patch helper (tracked changes, comments, hyperlinks, relationships). Other scripts reuse this.
- `scripts/fields_materialize.py` — materialize `SEQ`/`REF` field *display text* for deterministic headless rendering/QA.

**High-leverage utilities (also importable, but commonly invoked as CLIs):**
- `render_docx.py` — canonical DOCX → PNG renderer (optional PDF via `--emit_pdf`; do not deliver intermediates unless asked).
- `scripts/render_and_diff.py` — render + per-page image diff between two DOCXs.
- `scripts/content_controls.py` — list / wrap / fill Word content controls (SDTs) for forms/templates.
- `scripts/captions_and_crossrefs.py` — insert Caption paragraphs for tables/figures + optional bookmarks around caption numbers.
- `scripts/insert_ref_fields.py` — replace `[[REF:bookmark]]` markers with real `REF` fields (cross-references).
- `scripts/internal_nav.py` — add internal navigation links (static TOC + Top/Bottom + figN/tblN jump links).
- `scripts/style_lint.py` — report common formatting/style inconsistencies.
- `scripts/style_normalize.py` — conservative cleanup (clear run-level overrides; optional paragraph overrides).
- `scripts/redact_docx.py` — layout-preserving redaction/anonymization.
- `scripts/privacy_scrub.py` — remove personal metadata + `rsid*` attributes.
- `scripts/set_protection.py` — restrict editing (read-only / comments / forms).
- `scripts/comments_extract.py` — extract comments to JSON (text, author/date, resolved flag, anchored snippets).
- `scripts/comments_strip.py` — remove all comments (final-delivery mode).

**Audits / conversions / niche helpers:**
- `scripts/fields_report.py`, `scripts/heading_audit.py`, `scripts/section_audit.py`, `scripts/images_audit.py`, `scripts/footnotes_report.py`, `scripts/watermark_audit_remove.py`
- `scripts/xlsx_to_docx_table.py`, `scripts/docx_table_to_csv.py`
- `scripts/insert_toc.py`, `scripts/insert_note.py`, `scripts/apply_template_styles.py`, `scripts/accept_tracked_changes.py`, `scripts/make_fixtures.py`

**v7 additions (stress-test helpers):**
- `scripts/watermark_add.py` — add a detectable VML watermark object into an existing header.
- `scripts/comments_add.py` — add multiple comments (by paragraph substring match) and wire up comments.xml plumbing if needed.
- `scripts/comments_apply_patch.py` — append/replace comment text and mark/clear resolved state (`w:done=1`).
- `scripts/add_tracked_replacements.py` — generate tracked-change replacements (`<w:del>` + `<w:ins>`) in-place.
- `scripts/a11y_audit.py` — audit a11y issues; can also apply simple fixes via `--fix_table_headers` / `--fix_image_alt`.
- `scripts/flatten_ref_fields.py` — replace REF/PAGEREF field blocks with their cached visible text for deterministic rendering.

> `scripts/xlsx_to_docx_table.py` also marks header rows as repeating headers (`w:tblHeader`) to improve a11y and multi-page tables.

Examples:
- examples/end_to_end_smoke_test.md

> Note: `manifest.txt` is **machine-readable** and is used by download tooling. It must contain only relative file paths (one per line).


## Coverage map (scripts ↔ task guides)

This is a quick index so you can jump from a helper script to the right task guide.

### Layout & style
- `style_lint.py`, `style_normalize.py` → `tasks/style_lint_normalize.md`
- `apply_template_styles.py` → `tasks/templates_style_packs.md`
- `section_audit.py` → `tasks/sections_layout.md`
- `heading_audit.py` → `tasks/headings_numbering.md`

### Figures / images
- `images_audit.py`, `a11y_audit.py` → `tasks/images_figures.md`, `tasks/accessibility_a11y.md`
- `captions_and_crossrefs.py` → `tasks/captions_crossrefs.md`

### Tables / spreadsheets
- `xlsx_to_docx_table.py` → `tasks/tables_spreadsheets.md`
- `docx_table_to_csv.py` → `tasks/tables_spreadsheets.md`

### Fields & references
- `fields_report.py`, `fields_materialize.py` → `tasks/fields_update.md`
- `insert_ref_fields.py`, `flatten_ref_fields.py` → `tasks/fields_update.md`, `tasks/captions_crossrefs.md`
- `insert_toc.py` → `tasks/toc_workflow.md`

### Review lifecycle (comments / tracked changes)
- `add_tracked_replacements.py`, `accept_tracked_changes.py` → `tasks/clean_tracked_changes.md`
- `comments_add.py`, `comments_extract.py`, `comments_apply_patch.py`, `comments_strip.py` → `tasks/comments_manage.md`

### Privacy / publishing
- `privacy_scrub.py` → `tasks/privacy_scrub_metadata.md`
- `redact_docx.py` → `tasks/redaction_anonymization.md`
- `watermark_add.py`, `watermark_audit_remove.py` → `tasks/watermarks_background.md`

### Navigation & multi-doc assembly
- `internal_nav.py` → `tasks/navigation_internal_links.md`
- `merge_docx_append.py` → `tasks/multi_doc_merge.md`

### Forms & protection
- `content_controls.py` → `tasks/forms_content_controls.md`
- `set_protection.py` → `tasks/protection_restrict_editing.md`

### QA / regression
- `render_and_diff.py`, `render_docx.py` → `tasks/compare_diff.md`, `tasks/verify_render.md`
- `make_fixtures.py` → `tasks/fixtures_edge_cases.md`
- `docx_ooxml_patch.py` → used across guides for targeted patches

## Skill folder contents
- `tasks/` — task playbooks (what to do step-by-step)
- `ooxml/` — advanced OOXML patches (tracked changes, comments, hyperlinks, fields)
- `scripts/` — reusable helper scripts
- `examples/` — small runnable examples

## Default workflow (80/20)

**Rule of thumb:** every meaningful edit batch must end with a render + PNG review. No exceptions.
"80/20" here means: follow the simplest workflow that covers *most* DOCX tasks reliably.

**Golden path (don’t mix-and-match unless debugging):**
1. **Author/edit with `python-docx`** (paragraphs, runs, styles, tables, headers/footers).
2. **Render → inspect PNGs immediately** (DOCX → PNGs). Treat this as your feedback loop.
3. **Fix and repeat** until the PNGs are visually perfect.
4. **Only if needed**: use OOXML patching for tracked changes, comments, hyperlinks, or fields.
5. **Re-render and inspect again** after *any* OOXML patch or layout-sensitive change.
6. **Deliver only after the latest PNG review passes** (all pages, 100% zoom).

## Visual review (recommended)
Use the packaged renderer (dedicated LibreOffice profile + writable HOME):

```bash
python render_docx.py /mnt/data/input.docx --output_dir /mnt/data/out
# If debugging LibreOffice:
python render_docx.py /mnt/data/input.docx --output_dir /mnt/data/out --verbose
# Optional: also write <input_stem>.pdf to --output_dir (for debugging/archival):
python render_docx.py /mnt/data/input.docx --output_dir /mnt/data/out --emit_pdf
```

Then inspect the generated `page-<N>.png` files.

**Success criteria (render + visual QA):**
- PNGs exist for each page
- Page count matches expectations
- **Inspect every page at 100% zoom** (no “spot check” for final delivery)
- No clipping/overlap, no broken tables, no missing glyphs, no header/footer misplacement

**Note:** LibreOffice sometimes prints scary-looking stderr (e.g., `error : Unknown IO error`) even when output is correct. Treat the render as successful if the PNGs exist and look right (and if you used `--emit_pdf`, the PDF exists and is non-empty).

### What rendering does and doesn’t validate

- **Great for:** layout correctness, fonts, spacing, tables, headers/footers, and whether **tracked changes** visually appear.
- **Not reliable for:** **comments** (often not rendered in headless PDF export). For comments, also do **structural checks** (comments.xml + anchors + rels + content-types).

## Quality reminders
- Don’t ship visible defects (clipped/overlapping text, broken tables, unreadable glyphs).
- Don’t leak tool citation tokens into the DOCX (convert them to normal human citations).
- Prefer ASCII punctuation (avoid exotic Unicode hyphens/dashes that render inconsistently).

## Where to go next
- If the task is **reading/reviewing**: `tasks/read_review.md`
- If the task is **creating/editing**: `tasks/create_edit.md`
- If you need an **accessibility audit** (alt text, headings, tables, links): `tasks/accessibility_a11y.md`
- If you need to **extract or remove comments**: `tasks/comments_manage.md`
- If you need to **restrict editing / make read-only**: `tasks/protection_restrict_editing.md`
- If you need to **scrub personal metadata** (author/rsid/custom props): `tasks/privacy_scrub_metadata.md`
- If you need to **merge/append DOCXs**: `tasks/multi_doc_merge.md`
- If you need **format consistency / style cleanup**: `tasks/style_lint_normalize.md`
- If you need **forms / content controls (SDTs)**: `tasks/forms_content_controls.md`
- If you need **captions + cross-references**: `tasks/captions_crossrefs.md`
- If you need **redaction/anonymization**: `tasks/redaction_anonymization.md`
- If the task is **verification/raster review**: `tasks/verify_render.md`
- If your render looks wrong but content is right (stale fields): `tasks/fields_update.md`
- If you need a **Table of Contents**: `tasks/toc_workflow.md`
- If you need **internal navigation links** (static TOC + Back-to-TOC + Top/Bottom): `tasks/navigation_internal_links.md`
- If headings/numbering/TOC levels are messy: `tasks/headings_numbering.md`
- If you have mixed portrait/landscape or margin weirdness: `tasks/sections_layout.md`
- If images shift or overlap across renderers: `tasks/images_figures.md`
- If you need spreadsheet ↔ table round-tripping: `tasks/tables_spreadsheets.md`
- If you need **tracked changes (redlines)**: `ooxml/tracked_changes.md`
- If you need **comments**: `ooxml/comments.md`
- If you need **hyperlinks/fields/page numbers/headers**: `ooxml/hyperlinks_and_fields.md`
- If LibreOffice headless is failing: `troubleshooting/libreoffice_headless.md`
- If you need a **clean copy** with tracked changes accepted: `tasks/clean_tracked_changes.md`
- If you need to **diff two DOCXs** (render + per-page diff): `tasks/compare_diff.md`
- If you need **templates / style packs (DOTX)**: `tasks/templates_style_packs.md`
- If you need **watermark audit/removal**: `tasks/watermarks_background.md`
- If you need **true footnotes/endnotes**: `tasks/footnotes_endnotes.md`
- If you want reproducible fixtures for edge cases: `tasks/fixtures_edge_cases.md`

---PDF---
---
name: pdfs
description: Reliable, workflow-driven PDF processing: render → verify → operate → re-render/verify, covering reading, inspection, extraction, editing, forms, OCR, redaction, conversion, and diffing. Prefer authoring in DOCX or PPTX (then converting to PDF) for text-heavy docs or slide-like layouts; use ReportLab here for programmatic PDF generation.
---

# PDF Skill (Read • Inspect • Extract • Edit • Render • Forms • OCR • Redact • Convert • Diff)

This skill is designed for **reliable, workflow-driven** PDF work: **render -> verify -> operate -> re-render verify**.

## Before you touch PDFs: should this be DOCX/PPTX instead?

Even if the user asks for a PDF deliverable, the best workflow is often:

- **Text-heavy, business-doc layout (headings, TOC, long tables, rich lists)** -> use the **DOCX skill** to author, then convert to PDF with `lo_convert_to_pdf.py`.
- **Slide-like visual layout (charts, callouts, fixed positioning, figure captions)** -> use the **Slides skill** (PPTX) to author, then export to PDF.
- **Programmatic generation** -> ReportLab (this skill) is fine.

If you find yourself hand-tuning line breaks or typography in ReportLab, you probably picked the wrong authoring format.

---

## Core loop (always)

1) Render to images

```bash
python /home/oai/skills/pdfs/scripts/render_pdf.py input.pdf --out_dir /mnt/data/_renders/in --dpi 200
```

2) Inspect PNGs (tables/figures/layout are authoritative)

3) Perform the edit/extract/create

4) Re-render and compare

```bash
python /home/oai/skills/pdfs/scripts/compare_renders.py before.pdf after.pdf --out_dir /mnt/data/_diff --dpi 200
```

---

## Task index (progressive)

Start with the smallest task that answers the user:

### Read / review
- `tasks/read_review.md`

### Extract (text/layout/tables/images/attachments/forms)
- `tasks/extract.md`
- `tasks/coords.md` (coordinate sanity)

### Edit (merge/split/rotate/crop/watermark/paginate/encrypt/repair)
- `tasks/edit.md`
- `tasks/compare.md` (visual regression)

### Forms
- Fillable forms: `tasks/forms_annotations.md`
- Debugging/introspection: `tasks/forms_debugging.md`
- Non-fillable / stamping workflow: `tasks/forms_nonfillable.md`

### OCR
- `tasks/ocr.md`

### Preflight / normalize
- `tasks/preflight.md`

### Redaction
- `tasks/redact.md`

### Renderer parity
- `tasks/parity.md`

### Batch processing
- `tasks/batch.md`

### Create / convert
- `tasks/create.md`
- `tasks/convert.md`
- `tasks/js_tools.md` (pdf-lib, pdfjs)


---

## Package map (where things live)

This pack includes a `manifest.txt` that is a **pure list of relative file paths** used by download tooling.

Quick map:

- **tasks/** (what to do)
  - `read_review.md` - render-first reading/review
  - `extract.md` - extract text/layout/tables/images/attachments/forms
  - `coords.md` - coordinate system cheatsheet (PDF pt vs image px)
  - `edit.md` - merge/split/select/rotate/crop/watermark/paginate/encrypt/repair
  - `compare.md` - visual diff workflow
  - `forms_annotations.md` - fillable forms + appearance pitfalls + correctness checklist
  - `forms_debugging.md` - widget-level introspection + acceptable values
  - `forms_nonfillable.md` - stamp-by-boxes workflow for non-fillable forms
  - `ocr.md` - OCR scanned PDFs to searchable
  - `preflight.md` - quick triage + normalization guidance
  - `redact.md` - true redaction workflows
  - `parity.md` - render parity across engines
  - `batch.md` - batch helpers for corpora
  - `create.md` - choose reportlab/latex/html/docx/pptx pipeline
  - `convert.md` - docx/pptx/html/markdown/latex to PDF conversion
  - `js_tools.md` - pdf-lib/pdfjs helper CLIs

- **scripts/** (run these)
  - `render_pdf.py` - render to PNGs (pdfium or poppler)
  - `compare_renders.py` - render-and-diff two PDFs (pixel diff)
  - `pdf_inspect.py` - metadata/structure overview
  - `pdf_extract.py` - text/words/chars/tables/images/attachments/annots/forms
  - `pdf_edit.py` - editing toolkit (merge/split/select/rotate/crop/watermark/paginate/encrypt/repair/optimize)
  - `pdf_preflight.py` - preflight/triage warnings
  - `pdf_redact.py` - true redaction (remove underlying content)
  - `renderer_parity.py` - diff pdftoppm vs pdfium renders
  - `batch_pdf.py` - batch runner for common ops
  - `box_picker_html.py` - generate interactive HTML to pick rectangles -> JSON in PDF coords
  - `place_text_by_boxes.py` - stamp text/checkmarks into rectangles (non-fillable forms)
  - `ocr_pdf.py` - OCR wrapper
  - `html_to_pdf.py`, `md_to_pdf.py`, `latex_to_pdf.py`, `lo_convert_to_pdf.py` - conversion helpers

- **js/** (Node helpers)
  - `install_deps.sh` - installs pdf-lib + pdfjs-dist
  - `fill_form.mjs` - fill + optional flatten (supports flags and positional args)
  - `extract_form_fields.mjs` - list AcroForm fields
  - `extract_text_pdfjs.mjs` - extract text via pdfjs-dist

- **examples/**
  - `smoke_test.md` - runnable smoke flows

- **troubleshooting/**
  - `common.md` - common pitfalls and fixes

---

## Final deliverable expectations

- No clipped text, overlaps, black squares, or broken glyphs in rendered PNGs.
- Verify in at least **one** renderer (`pdfium` or `pdftoppm`). For tricky forms, verify in **two**.
- Remove intermediate artifacts from the deliverable folder (keep only final PDF(s)).
- Avoid Unicode dashes that some renderers mishandle; prefer ASCII `-`.
Analyzed
bash -lc cat /home/oai/skills/docx/tasks/create_edit.md | head -220
# Task: Create / edit a DOCX

## Default tool: python-docx
Use `python-docx` for:
- paragraphs/runs
- built-in styles (Title / Heading 1 / Heading 2)
- tables (structure + cell text + basic formatting)
- simple headers/footers and margins

## Practical python-docx gotchas

### 1) Header/footer tables require a width
When adding tables to headers/footers, `add_table` requires an explicit width:

```python
from docx.shared import Inches
from docx.enum.text import WD_ALIGN_PARAGRAPH

section = doc.sections[0]
footer = section.footer
table = footer.add_table(rows=1, cols=3, width=Inches(6.5))
# Align text inside each cell
table.rows[0].cells[0].paragraphs[0].alignment = WD_ALIGN_PARAGRAPH.LEFT
```

### 2) Fonts can require setting both `run.font.name` and `w:rFonts`
Some renderers/Word builds don’t respect only `run.font.name`:

```python
from docx.oxml.ns import qn

run.font.name = "Gill Sans"
run._element.rPr.rFonts.set(qn("w:ascii"), "Gill Sans")
run._element.rPr.rFonts.set(qn("w:hAnsi"), "Gill Sans")
```

### 3) “Clear header paragraph” isn’t always one call
If you need to replace an existing header paragraph, remove runs (or replace the paragraph XML). Avoid assuming a `clear()` method exists.

### 4) Tracked changes and comments are not first-class
If the user requests *real* tracked changes or *real* Word comments, plan for OOXML patching (see `ooxml/`).

## After every meaningful batch of edits: render and review
Use the loop from `tasks/verify_render.md` (DOCX → PNG) to avoid shipping layout defects. (Internally the renderer uses a PDF step; `--emit_pdf` can persist it if needed.)

## Output hygiene
Keep `/mnt/data` clean: deliverables only unless the user asks for intermediate render artifacts.
Analyzed
bash -lc python - <<'PY'
import importlib.util
print('pennylane', bool(importlib.util.find_spec('pennylane')))
print('numpy', bool(importlib.util.find_spec('numpy')))
print('matplotlib', bool(importlib.util.find_spec('matplotlib')))
print('docx', bool(importlib.util.find_spec('docx')))
PY
pennylane False
numpy True
matplotlib True
docx True
Shaping the manuscript
I’m organizing 50 compact, concept-specific pages, each pairing an equation with a practical explanation, a conceptual chart, assumptions, and a visual prompt suitable for later illustration.

Worked for 2m 55s
Done

Reading document and PDF skills
bash -lc cat /home/oai/skills/docx/SKILL.md && printf '\n---PDF---\n' && cat /home/oai/skills/pdfs/SKILL.md
---
name: docx
description: Create, edit, redline, and comment on `.docx` files inside the container, with a strict render-and-verify workflow. Use `render_docx.py` to generate page PNGs (and optional PDF) for visual QA, then iterate until layout is flawless before delivering the final DOCX. 
---


# DOCX Skill (Read • Create • Edit • Redline • Comment)

Use this skill when you need to create or modify `.docx` files **in this container environment** and verify them visually.

## Non-negotiable: render → inspect PNGs → iterate

**You do not “know” a DOCX is satisfactory until you’ve rendered it and visually inspected page images.**  
DOCX text extraction (or reading XML) will miss layout defects: clipping, overlap, missing glyphs, broken tables, spacing drift, and header/footer issues.

**Shipping gate:** before delivering any DOCX, you must:
- Run `render_docx.py` to produce `page-<N>.png` images (optionally also a PDF with `--emit_pdf`)
- Open the PNGs (100% zoom) and confirm every page is clean
- If anything looks off, fix the DOCX and **re-render** (repeat until flawless)

If rendering fails, fix rendering first (LibreOffice profile/HOME) rather than guessing.

**Deliverable discipline:** Rendered artifacts (PNGs and optional PDFs) are for internal QA only. Unless the user explicitly asks for intermediates, **return only the requested final deliverable** (e.g., when the task asks for a DOCX, deliver the DOCX — not page images or PDFs).



## Quick start (common one-liners)

```bash
# 1) Render any DOCX to PNGs (visual QA)
python render_docx.py input.docx --output_dir out

# 2) Remove reviewer comments (finalization)
python scripts/comments_strip.py input.docx --out no_comments.docx

# 3) Accept tracked changes (finalization)
python scripts/accept_tracked_changes.py input.docx --mode accept --out accepted.docx

# 4) Accessibility audit (+ optional safe fixes)
python scripts/a11y_audit.py input.docx
python scripts/a11y_audit.py input.docx --out_json a11y_report.json
python scripts/a11y_audit.py input.docx --fix_image_alt from_filename --out a11y_fixed.docx

# 5) Redact sensitive text (layout-preserving by default)
python scripts/redact_docx.py input.docx redacted.docx --emails --phones
```

## Package layout

This skill is organized for progressive discovery: start here, then jump into task- or OOXML-specific docs.

DOCS SKILL PACKAGE

Root:
- SKILL.md: short overview + routing
- manifest.txt: machine-readable list of files to download (one relative path per line)
- render_docx.py: canonical DOCX→PNG renderer (container-safe LO profile + writable HOME + verbose logs)

Tasks:
- tasks/read_review.md
- tasks/create_edit.md
- tasks/verify_render.md
- tasks/accessibility_a11y.md
- tasks/comments_manage.md
- tasks/protection_restrict_editing.md
- tasks/privacy_scrub_metadata.md
- tasks/multi_doc_merge.md
- tasks/style_lint_normalize.md
- tasks/forms_content_controls.md
- tasks/captions_crossrefs.md
- tasks/redaction_anonymization.md
- tasks/clean_tracked_changes.md
- tasks/compare_diff.md
- tasks/templates_style_packs.md
- tasks/watermarks_background.md
- tasks/footnotes_endnotes.md
- tasks/fixtures_edge_cases.md
- tasks/navigation_internal_links.md

OOXML:
- ooxml/tracked_changes.md
- ooxml/comments.md
- ooxml/hyperlinks_and_fields.md
- ooxml/rels_and_content_types.md

Troubleshooting:
- troubleshooting/libreoffice_headless.md
- troubleshooting/run_splitting.md

Scripts:

**Core building blocks (importable helpers):**
- `scripts/docx_ooxml_patch.py` — low-level OOXML patch helper (tracked changes, comments, hyperlinks, relationships). Other scripts reuse this.
- `scripts/fields_materialize.py` — materialize `SEQ`/`REF` field *display text* for deterministic headless rendering/QA.

**High-leverage utilities (also importable, but commonly invoked as CLIs):**
- `render_docx.py` — canonical DOCX → PNG renderer (optional PDF via `--emit_pdf`; do not deliver intermediates unless asked).
- `scripts/render_and_diff.py` — render + per-page image diff between two DOCXs.
- `scripts/content_controls.py` — list / wrap / fill Word content controls (SDTs) for forms/templates.
- `scripts/captions_and_crossrefs.py` — insert Caption paragraphs for tables/figures + optional bookmarks around caption numbers.
- `scripts/insert_ref_fields.py` — replace `[[REF:bookmark]]` markers with real `REF` fields (cross-references).
- `scripts/internal_nav.py` — add internal navigation links (static TOC + Top/Bottom + figN/tblN jump links).
- `scripts/style_lint.py` — report common formatting/style inconsistencies.
- `scripts/style_normalize.py` — conservative cleanup (clear run-level overrides; optional paragraph overrides).
- `scripts/redact_docx.py` — layout-preserving redaction/anonymization.
- `scripts/privacy_scrub.py` — remove personal metadata + `rsid*` attributes.
- `scripts/set_protection.py` — restrict editing (read-only / comments / forms).
- `scripts/comments_extract.py` — extract comments to JSON (text, author/date, resolved flag, anchored snippets).
- `scripts/comments_strip.py` — remove all comments (final-delivery mode).

**Audits / conversions / niche helpers:**
- `scripts/fields_report.py`, `scripts/heading_audit.py`, `scripts/section_audit.py`, `scripts/images_audit.py`, `scripts/footnotes_report.py`, `scripts/watermark_audit_remove.py`
- `scripts/xlsx_to_docx_table.py`, `scripts/docx_table_to_csv.py`
- `scripts/insert_toc.py`, `scripts/insert_note.py`, `scripts/apply_template_styles.py`, `scripts/accept_tracked_changes.py`, `scripts/make_fixtures.py`

**v7 additions (stress-test helpers):**
- `scripts/watermark_add.py` — add a detectable VML watermark object into an existing header.
- `scripts/comments_add.py` — add multiple comments (by paragraph substring match) and wire up comments.xml plumbing if needed.
- `scripts/comments_apply_patch.py` — append/replace comment text and mark/clear resolved state (`w:done=1`).
- `scripts/add_tracked_replacements.py` — generate tracked-change replacements (`<w:del>` + `<w:ins>`) in-place.
- `scripts/a11y_audit.py` — audit a11y issues; can also apply simple fixes via `--fix_table_headers` / `--fix_image_alt`.
- `scripts/flatten_ref_fields.py` — replace REF/PAGEREF field blocks with their cached visible text for deterministic rendering.

> `scripts/xlsx_to_docx_table.py` also marks header rows as repeating headers (`w:tblHeader`) to improve a11y and multi-page tables.

Examples:
- examples/end_to_end_smoke_test.md

> Note: `manifest.txt` is **machine-readable** and is used by download tooling. It must contain only relative file paths (one per line).


## Coverage map (scripts ↔ task guides)

This is a quick index so you can jump from a helper script to the right task guide.

### Layout & style
- `style_lint.py`, `style_normalize.py` → `tasks/style_lint_normalize.md`
- `apply_template_styles.py` → `tasks/templates_style_packs.md`
- `section_audit.py` → `tasks/sections_layout.md`
- `heading_audit.py` → `tasks/headings_numbering.md`

### Figures / images
- `images_audit.py`, `a11y_audit.py` → `tasks/images_figures.md`, `tasks/accessibility_a11y.md`
- `captions_and_crossrefs.py` → `tasks/captions_crossrefs.md`

### Tables / spreadsheets
- `xlsx_to_docx_table.py` → `tasks/tables_spreadsheets.md`
- `docx_table_to_csv.py` → `tasks/tables_spreadsheets.md`

### Fields & references
- `fields_report.py`, `fields_materialize.py` → `tasks/fields_update.md`
- `insert_ref_fields.py`, `flatten_ref_fields.py` → `tasks/fields_update.md`, `tasks/captions_crossrefs.md`
- `insert_toc.py` → `tasks/toc_workflow.md`

### Review lifecycle (comments / tracked changes)
- `add_tracked_replacements.py`, `accept_tracked_changes.py` → `tasks/clean_tracked_changes.md`
- `comments_add.py`, `comments_extract.py`, `comments_apply_patch.py`, `comments_strip.py` → `tasks/comments_manage.md`

### Privacy / publishing
- `privacy_scrub.py` → `tasks/privacy_scrub_metadata.md`
- `redact_docx.py` → `tasks/redaction_anonymization.md`
- `watermark_add.py`, `watermark_audit_remove.py` → `tasks/watermarks_background.md`

### Navigation & multi-doc assembly
- `internal_nav.py` → `tasks/navigation_internal_links.md`
- `merge_docx_append.py` → `tasks/multi_doc_merge.md`

### Forms & protection
- `content_controls.py` → `tasks/forms_content_controls.md`
- `set_protection.py` → `tasks/protection_restrict_editing.md`

### QA / regression
- `render_and_diff.py`, `render_docx.py` → `tasks/compare_diff.md`, `tasks/verify_render.md`
- `make_fixtures.py` → `tasks/fixtures_edge_cases.md`
- `docx_ooxml_patch.py` → used across guides for targeted patches

## Skill folder contents
- `tasks/` — task playbooks (what to do step-by-step)
- `ooxml/` — advanced OOXML patches (tracked changes, comments, hyperlinks, fields)
- `scripts/` — reusable helper scripts
- `examples/` — small runnable examples

## Default workflow (80/20)

**Rule of thumb:** every meaningful edit batch must end with a render + PNG review. No exceptions.
"80/20" here means: follow the simplest workflow that covers *most* DOCX tasks reliably.

**Golden path (don’t mix-and-match unless debugging):**
1. **Author/edit with `python-docx`** (paragraphs, runs, styles, tables, headers/footers).
2. **Render → inspect PNGs immediately** (DOCX → PNGs). Treat this as your feedback loop.
3. **Fix and repeat** until the PNGs are visually perfect.
4. **Only if needed**: use OOXML patching for tracked changes, comments, hyperlinks, or fields.
5. **Re-render and inspect again** after *any* OOXML patch or layout-sensitive change.
6. **Deliver only after the latest PNG review passes** (all pages, 100% zoom).

## Visual review (recommended)
Use the packaged renderer (dedicated LibreOffice profile + writable HOME):

```bash
python render_docx.py /mnt/data/input.docx --output_dir /mnt/data/out
# If debugging LibreOffice:
python render_docx.py /mnt/data/input.docx --output_dir /mnt/data/out --verbose
# Optional: also write <input_stem>.pdf to --output_dir (for debugging/archival):
python render_docx.py /mnt/data/input.docx --output_dir /mnt/data/out --emit_pdf
```

Then inspect the generated `page-<N>.png` files.

**Success criteria (render + visual QA):**
- PNGs exist for each page
- Page count matches expectations
- **Inspect every page at 100% zoom** (no “spot check” for final delivery)
- No clipping/overlap, no broken tables, no missing glyphs, no header/footer misplacement

**Note:** LibreOffice sometimes prints scary-looking stderr (e.g., `error : Unknown IO error`) even when output is correct. Treat the render as successful if the PNGs exist and look right (and if you used `--emit_pdf`, the PDF exists and is non-empty).

### What rendering does and doesn’t validate

- **Great for:** layout correctness, fonts, spacing, tables, headers/footers, and whether **tracked changes** visually appear.
- **Not reliable for:** **comments** (often not rendered in headless PDF export). For comments, also do **structural checks** (comments.xml + anchors + rels + content-types).

## Quality reminders
- Don’t ship visible defects (clipped/overlapping text, broken tables, unreadable glyphs).
- Don’t leak tool citation tokens into the DOCX (convert them to normal human citations).
- Prefer ASCII punctuation (avoid exotic Unicode hyphens/dashes that render inconsistently).

## Where to go next
- If the task is **reading/reviewing**: `tasks/read_review.md`
- If the task is **creating/editing**: `tasks/create_edit.md`
- If you need an **accessibility audit** (alt text, headings, tables, links): `tasks/accessibility_a11y.md`
- If you need to **extract or remove comments**: `tasks/comments_manage.md`
- If you need to **restrict editing / make read-only**: `tasks/protection_restrict_editing.md`
- If you need to **scrub personal metadata** (author/rsid/custom props): `tasks/privacy_scrub_metadata.md`
- If you need to **merge/append DOCXs**: `tasks/multi_doc_merge.md`
- If you need **format consistency / style cleanup**: `tasks/style_lint_normalize.md`
- If you need **forms / content controls (SDTs)**: `tasks/forms_content_controls.md`
- If you need **captions + cross-references**: `tasks/captions_crossrefs.md`
- If you need **redaction/anonymization**: `tasks/redaction_anonymization.md`
- If the task is **verification/raster review**: `tasks/verify_render.md`
- If your render looks wrong but content is right (stale fields): `tasks/fields_update.md`
- If you need a **Table of Contents**: `tasks/toc_workflow.md`
- If you need **internal navigation links** (static TOC + Back-to-TOC + Top/Bottom): `tasks/navigation_internal_links.md`
- If headings/numbering/TOC levels are messy: `tasks/headings_numbering.md`
- If you have mixed portrait/landscape or margin weirdness: `tasks/sections_layout.md`
- If images shift or overlap across renderers: `tasks/images_figures.md`
- If you need spreadsheet ↔ table round-tripping: `tasks/tables_spreadsheets.md`
- If you need **tracked changes (redlines)**: `ooxml/tracked_changes.md`
- If you need **comments**: `ooxml/comments.md`
- If you need **hyperlinks/fields/page numbers/headers**: `ooxml/hyperlinks_and_fields.md`
- If LibreOffice headless is failing: `troubleshooting/libreoffice_headless.md`
- If you need a **clean copy** with tracked changes accepted: `tasks/clean_tracked_changes.md`
- If you need to **diff two DOCXs** (render + per-page diff): `tasks/compare_diff.md`
- If you need **templates / style packs (DOTX)**: `tasks/templates_style_packs.md`
- If you need **watermark audit/removal**: `tasks/watermarks_background.md`
- If you need **true footnotes/endnotes**: `tasks/footnotes_endnotes.md`
- If you want reproducible fixtures for edge cases: `tasks/fixtures_edge_cases.md`

---PDF---
---
name: pdfs
description: Reliable, workflow-driven PDF processing: render → verify → operate → re-render/verify, covering reading, inspection, extraction, editing, forms, OCR, redaction, conversion, and diffing. Prefer authoring in DOCX or PPTX (then converting to PDF) for text-heavy docs or slide-like layouts; use ReportLab here for programmatic PDF generation.
---

# PDF Skill (Read • Inspect • Extract • Edit • Render • Forms • OCR • Redact • Convert • Diff)

This skill is designed for **reliable, workflow-driven** PDF work: **render -> verify -> operate -> re-render verify**.

## Before you touch PDFs: should this be DOCX/PPTX instead?

Even if the user asks for a PDF deliverable, the best workflow is often:

- **Text-heavy, business-doc layout (headings, TOC, long tables, rich lists)** -> use the **DOCX skill** to author, then convert to PDF with `lo_convert_to_pdf.py`.
- **Slide-like visual layout (charts, callouts, fixed positioning, figure captions)** -> use the **Slides skill** (PPTX) to author, then export to PDF.
- **Programmatic generation** -> ReportLab (this skill) is fine.

If you find yourself hand-tuning line breaks or typography in ReportLab, you probably picked the wrong authoring format.

---

## Core loop (always)

1) Render to images

```bash
python /home/oai/skills/pdfs/scripts/render_pdf.py input.pdf --out_dir /mnt/data/_renders/in --dpi 200
```

2) Inspect PNGs (tables/figures/layout are authoritative)

3) Perform the edit/extract/create

4) Re-render and compare

```bash
python /home/oai/skills/pdfs/scripts/compare_renders.py before.pdf after.pdf --out_dir /mnt/data/_diff --dpi 200
```

---

## Task index (progressive)

Start with the smallest task that answers the user:

### Read / review
- `tasks/read_review.md`

### Extract (text/layout/tables/images/attachments/forms)
- `tasks/extract.md`
- `tasks/coords.md` (coordinate sanity)

### Edit (merge/split/rotate/crop/watermark/paginate/encrypt/repair)
- `tasks/edit.md`
- `tasks/compare.md` (visual regression)

### Forms
- Fillable forms: `tasks/forms_annotations.md`
- Debugging/introspection: `tasks/forms_debugging.md`
- Non-fillable / stamping workflow: `tasks/forms_nonfillable.md`

### OCR
- `tasks/ocr.md`

### Preflight / normalize
- `tasks/preflight.md`

### Redaction
- `tasks/redact.md`

### Renderer parity
- `tasks/parity.md`

### Batch processing
- `tasks/batch.md`

### Create / convert
- `tasks/create.md`
- `tasks/convert.md`
- `tasks/js_tools.md` (pdf-lib, pdfjs)


---

## Package map (where things live)

This pack includes a `manifest.txt` that is a **pure list of relative file paths** used by download tooling.

Quick map:

- **tasks/** (what to do)
  - `read_review.md` - render-first reading/review
  - `extract.md` - extract text/layout/tables/images/attachments/forms
  - `coords.md` - coordinate system cheatsheet (PDF pt vs image px)
  - `edit.md` - merge/split/select/rotate/crop/watermark/paginate/encrypt/repair
  - `compare.md` - visual diff workflow
  - `forms_annotations.md` - fillable forms + appearance pitfalls + correctness checklist
  - `forms_debugging.md` - widget-level introspection + acceptable values
  - `forms_nonfillable.md` - stamp-by-boxes workflow for non-fillable forms
  - `ocr.md` - OCR scanned PDFs to searchable
  - `preflight.md` - quick triage + normalization guidance
  - `redact.md` - true redaction workflows
  - `parity.md` - render parity across engines
  - `batch.md` - batch helpers for corpora
  - `create.md` - choose reportlab/latex/html/docx/pptx pipeline
  - `convert.md` - docx/pptx/html/markdown/latex to PDF conversion
  - `js_tools.md` - pdf-lib/pdfjs helper CLIs

- **scripts/** (run these)
  - `render_pdf.py` - render to PNGs (pdfium or poppler)
  - `compare_renders.py` - render-and-diff two PDFs (pixel diff)
  - `pdf_inspect.py` - metadata/structure overview
  - `pdf_extract.py` - text/words/chars/tables/images/attachments/annots/forms
  - `pdf_edit.py` - editing toolkit (merge/split/select/rotate/crop/watermark/paginate/encrypt/repair/optimize)
  - `pdf_preflight.py` - preflight/triage warnings
  - `pdf_redact.py` - true redaction (remove underlying content)
  - `renderer_parity.py` - diff pdftoppm vs pdfium renders
  - `batch_pdf.py` - batch runner for common ops
  - `box_picker_html.py` - generate interactive HTML to pick rectangles -> JSON in PDF coords
  - `place_text_by_boxes.py` - stamp text/checkmarks into rectangles (non-fillable forms)
  - `ocr_pdf.py` - OCR wrapper
  - `html_to_pdf.py`, `md_to_pdf.py`, `latex_to_pdf.py`, `lo_convert_to_pdf.py` - conversion helpers

- **js/** (Node helpers)
  - `install_deps.sh` - installs pdf-lib + pdfjs-dist
  - `fill_form.mjs` - fill + optional flatten (supports flags and positional args)
  - `extract_form_fields.mjs` - list AcroForm fields
  - `extract_text_pdfjs.mjs` - extract text via pdfjs-dist

- **examples/**
  - `smoke_test.md` - runnable smoke flows

- **troubleshooting/**
  - `common.md` - common pitfalls and fixes

---

## Final deliverable expectations

- No clipped text, overlaps, black squares, or broken glyphs in rendered PNGs.
- Verify in at least **one** renderer (`pdfium` or `pdftoppm`). For tricky forms, verify in **two**.
- Remove intermediate artifacts from the deliverable folder (keep only final PDF(s)).
- Avoid Unicode dashes that some renderers mishandle; prefer ASCII `-`.
Building the manuscript
I’m producing 50 illustrated equation pages, each with a distinct conceptual graph, practical explanation, visual prompt, and companion simulation data. I’m also varying the associated circuit and entropy profile page by page.

Checking PennyLane availability
bash -lc python - <<'PY'
try:
 import pennylane as qml
 print('pennylane', qml.__version__)
except Exception as e:
 print('NO_PENNYLANE', e)
PY
NO_PENNYLANE No module named 'pennylane'
Analyzed
bash -lc mkdir -p /mnt/data/equation_atlas_1_50/assets /mnt/data/equation_atlas_1_50/rendered && cat > /mnt/data/equation_atlas_1_50/quantum_rgb_page_circuits.py <<'PY'
"""NumPy state-vector circuit generator for pages 1-50.

A lightweight PennyLane-inspired 3-qubit circuit family. No PennyLane dependency is
required. Each page gets deterministic but distinct rotation parameters, topology,
depth, final statevector, mean single-qubit entanglement entropy, measurement
Shannon entropy, and a local entropy sweep/range.
"""
from __future__ import annotations
import json, csv, math
from pathlib import Path
import numpy as np

ROOT = Path(__file__).resolve().parent
OUT_CSV = ROOT / "page_circuit_entropy.csv"
OUT_JSON = ROOT / "page_circuit_states.json"
OUT_SWEEPS = ROOT / "page_entropy_sweeps.npz"

I2 = np.eye(2, dtype=complex)
X = np.array([[0,1],[1,0]], dtype=complex)
Z = np.array([[1,0],[0,-1]], dtype=complex)
H = np.array([[1,1],[1,-1]], dtype=complex) / np.sqrt(2)


def RX(theta):
    c, s = np.cos(theta/2), np.sin(theta/2)
    return np.array([[c,-1j*s],[-1j*s,c]], dtype=complex)

def RY(theta):
    c, s = np.cos(theta/2), np.sin(theta/2)
    return np.array([[c,-s],[s,c]], dtype=complex)

def RZ(theta):
    return np.array([[np.exp(-1j*theta/2),0],[0,np.exp(1j*theta/2)]], dtype=complex)

def kron3(a,b,c): return np.kron(np.kron(a,b),c)

def one_qubit_op(U, wire):
    mats=[I2,I2,I2]; mats[wire]=U
    return kron3(*mats)

def apply_one(state,U,wire): return one_qubit_op(U,wire) @ state

def cnot_matrix(control,target):
    U=np.zeros((8,8),dtype=complex)
    for i in range(8):
        bits=[(i>>2)&1,(i>>1)&1,i&1]
        out=bits.copy()
        if bits[control]: out[target]^=1
        j=(out[0]<<2)|(out[1]<<1)|out[2]
        U[j,i]=1
    return U

def cz_matrix(a,b):
    U=np.eye(8,dtype=complex)
    for i in range(8):
        bits=[(i>>2)&1,(i>>1)&1,i&1]
        if bits[a] and bits[b]: U[i,i]=-1
    return U

def reduced_density_single(state, wire):
    psi=state.reshape(2,2,2)
    perm=[wire]+[w for w in range(3) if w!=wire]
    psi=np.transpose(psi,perm).reshape(2,-1)
    return psi @ psi.conj().T

def vn_entropy(rho):
    vals=np.linalg.eigvalsh(rho).real
    vals=np.clip(vals,1e-15,1)
    return float(-np.sum(vals*np.log2(vals)))

def shannon_entropy(state):
    p=np.abs(state)**2
    p=np.clip(p,1e-15,1)
    return float(-np.sum(p*np.log2(p)))

def page_parameters(page):
    # Quasi-periodic deterministic angles, mapped to [0, 2pi).
    g=(math.sqrt(5)-1)/2
    r=2*np.pi*((page*g + 0.071) % 1)
    gg=2*np.pi*((page*g*g + 0.317) % 1)
    b=2*np.pi*((page*np.sqrt(2)/2 + 0.619) % 1)
    phases=np.array([
        2*np.pi*((page*np.sqrt(3)/3 + 0.113)%1),
        2*np.pi*((page*np.sqrt(7)/5 + 0.271)%1),
        2*np.pi*((page*np.sqrt(11)/7 + 0.419)%1),
    ])
    delta=0.16 + 0.006*(page%11)  # radians, local range half-width
    depth=2 + page%3
    topo=page%4
    return np.array([r,gg,b]), phases, delta, depth, topo

def run_page(page, sweep=0.0):
    angles, phases, delta, depth, topo = page_parameters(page)
    # Sweep all three channels with different couplings to avoid trivial shifts.
    angles = angles + sweep*delta*np.array([1.0,-0.73,0.41])
    phases = phases + sweep*delta*np.array([0.33,0.58,-0.27])
    state=np.zeros(8,dtype=complex); state[0]=1
    # initial superposition changes subtly by page parity
    if page%2==0:
        state=apply_one(state,H,page%3)
    for layer in range(depth):
        for w in range(3):
            theta=angles[w]*(1+0.07*layer) + 0.03*page*(w+1)
            phi=phases[w]*(1-0.05*layer) + 0.019*layer*(page%7)
            gate_sel=(page+layer+w)%3
            if gate_sel==0:
                state=apply_one(state,RY(theta),w)
            elif gate_sel==1:
                state=apply_one(state,RX(theta),w)
            else:
                state=apply_one(state,RY(theta),w)
            state=apply_one(state,RZ(phi),w)
        if topo==0:
            pairs=[(0,1),(1,2)]
        elif topo==1:
            pairs=[(1,2),(2,0)]
        elif topo==2:
            pairs=[(2,0),(0,1)]
        else:
            pairs=[(0,2),(2,1)]
        c,t=pairs[layer%len(pairs)]
        state=cnot_matrix(c,t)@state
        if (page+layer)%3==0:
            a,b=(c+1)%3,(t+1)%3
            if a!=b: state=cz_matrix(a,b)@state
    state=state/np.linalg.norm(state)
    ent=[vn_entropy(reduced_density_single(state,w)) for w in range(3)]
    return state, ent, shannon_entropy(state)

def circuit_ops(page):
    angles, phases, delta, depth, topo=page_parameters(page)
    names=['R','G','B']
    ops=[]
    if page%2==0: ops.append(f"H(wire={page%3})")
    for layer in range(depth):
        for w in range(3):
            gate='RY' if (page+layer+w)%3 != 1 else 'RX'
            ops.append(f"{gate}({names[w]}_theta*{1+0.07*layer:.2f}+{0.03*page*(w+1):.3f}, wire={w})")
            ops.append(f"RZ({names[w]}_phi*{1-0.05*layer:.2f}+{0.019*layer*(page%7):.3f}, wire={w})")
        pairs=[[(0,1),(1,2)],[(1,2),(2,0)],[(2,0),(0,1)],[(0,2),(2,1)]][topo]
        c,t=pairs[layer%len(pairs)]
        ops.append(f"CNOT(control={c}, target={t})")
        if (page+layer)%3==0:
            a,b=(c+1)%3,(t+1)%3
            if a!=b: ops.append(f"CZ(wires=({a},{b}))")
    return ops

def complex_pairs(state):
    return [[float(z.real),float(z.imag)] for z in state]

def generate_all():
    rows=[]; states={}; sweeps={}
    grid=np.linspace(-1,1,81)
    for page in range(1,51):
        angles, phases, delta, depth, topo=page_parameters(page)
        state, ent, sh=run_page(page,0.0)
        curve=[]
        for s in grid:
            _, e, _=run_page(page,float(s))
            curve.append(float(np.mean(e)))
        curve=np.array(curve)
        mean_ent=float(np.mean(ent))
        row={
            'page':page,
            'depth':depth,
            'topology_id':topo,
            'R_theta':float(angles[0]), 'G_theta':float(angles[1]), 'B_theta':float(angles[2]),
            'R_theta_min':float(angles[0]-delta), 'R_theta_max':float(angles[0]+delta),
            'G_theta_min':float(angles[1]-0.73*delta), 'G_theta_max':float(angles[1]+0.73*delta),
            'B_theta_min':float(angles[2]-0.41*delta), 'B_theta_max':float(angles[2]+0.41*delta),
            'entropy_R':ent[0], 'entropy_G':ent[1], 'entropy_B':ent[2],
            'mean_entanglement_entropy':mean_ent,
            'entropy_range_min':float(curve.min()), 'entropy_range_max':float(curve.max()),
            'measurement_shannon_entropy':sh,
        }
        rows.append(row)
        states[str(page)]={
            'parameters':row,
            'ops':circuit_ops(page),
            'statevector_real_imag':complex_pairs(state),
        }
        sweeps[f'page_{page:03d}_sweep']=grid
        sweeps[f'page_{page:03d}_entropy']=curve
    with OUT_CSV.open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0].keys())); w.writeheader(); w.writerows(rows)
    OUT_JSON.write_text(json.dumps(states,indent=2))
    np.savez_compressed(OUT_SWEEPS,**sweeps)
    print(f"generated {len(rows)} page circuits")
    print(f"mean entropy: {np.mean([r['mean_entanglement_entropy'] for r in rows]):.6f}")
    print(f"entropy span across pages: {min(r['entropy_range_min'] for r in rows):.6f} .. {max(r['entropy_range_max'] for r in rows):.6f}")

if __name__=='__main__':
    generate_all()
PY
python /mnt/data/equation_atlas_1_50/quantum_rgb_page_circuits.py
head -3 /mnt/data/equation_atlas_1_50/page_circuit_entropy.csv
generated 50 page circuits
mean entropy: 0.601231
entropy span across pages: 0.002841 .. 0.957476
page,depth,topology_id,R_theta,G_theta,B_theta,R_theta_min,R_theta_max,G_theta_min,G_theta_max,B_theta_min,B_theta_max,entropy_R,entropy_G,entropy_B,mean_entanglement_entropy,entropy_range_min,entropy_range_max,measurement_shannon_entropy
1,3,1,4.329328234260684,4.391732972104583,2.0489893361229448,4.163328234260684,4.495328234260684,4.270552972104583,4.512912972104583,1.9809293361229448,2.1170493361229448,0.8012862119201851,0.8228204440801172,0.38364924149686186,0.669251965832388,0.6562234289476057,0.6739835919825007,2.664470058691692
2,4,2,1.9293650045320307,0.5085108946536494,0.20868696710172413,1.7573650045320308,2.1013650045320307,0.3829508946536494,0.6340708946536494,0.13816696710172413,0.2792069671017241,0.9805621922856578,0.5486620775064668,0.9845698896324954,0.8379313864748733,0.7980351017413563,0.924211687577241,2.350784266697305
Creating Equation Atlas Manuscript
bash -lc cat > /mnt/data/equation_atlas_1_50/build_book.py <<'PY'
from pathlib import Path
import csv, math, textwrap
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from docx import Document
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT=Path(__file__).resolve().parent
ASSETS=ROOT/'assets'; ASSETS.mkdir(exist_ok=True)
OUT=ROOT/'Equation_Atlas_Pages_1_50.docx'

with (ROOT/'page_circuit_entropy.csv').open() as f:
    entrows={int(r['page']):r for r in csv.DictReader(f)}

# title, mathtext equation, explanation, AI lens, image prompt
PAGES=[
(1,"Bayes' Theorem",r"P(A\mid B)=\frac{P(B\mid A)P(A)}{P(B)}",
"Bayes' theorem is the algebra of belief revision. A prior belief about A is multiplied by how compatible new evidence B is with A, then normalized by the overall probability of observing B. The equation is simple, but its consequence is profound: evidence does not create belief from nothing; it reshapes an existing distribution.",
"Bayesian reasoning appears whenever an AI system must combine uncertain evidence with previous knowledge. Probabilistic classifiers, latent-variable models, Bayesian optimization, filtering, and uncertainty estimation all reuse this pattern. The practical discipline is to separate what the model believed before the observation from what the observation actually supports.",
"A luminous probability landscape folding from prior to posterior, three translucent distributions intersecting around a single observation, scientific infographic, deep space mathematical aesthetic, no readable text."),
(2,"Log-Likelihood",r"\mathcal{L}(\theta)=\sum_i\log p(x_i\mid\theta)",
"The log-likelihood turns a product of many probabilities into a sum. That mathematical conversion is more than convenience: products of tiny probabilities can underflow numerically, while sums of logarithms remain stable. Maximizing log-likelihood is equivalent to maximizing likelihood because the logarithm is monotonic.",
"Most modern learning objectives are log-probability objectives in disguise. Language models minimize negative token log-likelihood; density models maximize log probability of observed data; probabilistic decoders use the same structure. The log scale also makes individual examples additive, so minibatches can estimate the full-data objective efficiently.",
"A field of probability particles collapsing into a smooth logarithmic energy surface, additive evidence streams converging on a parameter peak, elegant scientific visualization, no text."),
(3,"Maximum Likelihood Estimation",r"\hat{\theta}=\arg\max_{\theta}\prod_i p(x_i\mid\theta)",
"Maximum likelihood estimation chooses the parameter value that makes the observed dataset most probable under the model. It is a data-fitting principle: among candidate worlds defined by different parameters, select the one in which the evidence looks least surprising.",
"Training a neural network with cross-entropy is often maximum likelihood performed through gradient descent. The model class determines what distributions are possible; MLE decides which member of that class best explains the training set. Its limitation is equally important: the method optimizes fit to observed data, not automatically robustness, causality, fairness, or calibration.",
"A mountain-like likelihood surface with a bright parameter trajectory reaching the maximum, abstract neural geometry surrounding the peak, cinematic scientific rendering, no text."),
(4,"Entropy",r"H(X)=-\sum_x p(x)\log p(x)",
"Entropy measures uncertainty in a probability distribution. A distribution concentrated on one outcome has low entropy; a distribution spread evenly across many outcomes has high entropy. The logarithm makes independent uncertainties additive and gives entropy its information-theoretic interpretation in bits when base-2 logs are used.",
"In AI, entropy can quantify predictive uncertainty, encourage exploration, regularize policies, measure token diversity, or reveal how concentrated an attention or class distribution has become. High entropy is not inherently good or bad: sometimes it means useful diversity, and sometimes it means the model has no idea what to predict.",
"A probability simplex transforming from a sharp single spike to an evenly distributed constellation, entropy represented as expanding informational volume, minimalist scientific art, no labels."),
(5,"Cross-Entropy",r"H(p,q)=-\sum_x p(x)\log q(x)",
"Cross-entropy measures the coding cost incurred when the true distribution is p but predictions are made using q. It becomes small when q places probability mass where p does, and it grows sharply when the model assigns low probability to events that are actually correct.",
"Classification networks typically minimize cross-entropy between target labels and predicted softmax probabilities. For one-hot targets, the loss reduces to the negative log probability of the correct class. That makes the training signal interpretable: the model is punished most when it is confidently wrong.",
"Two probability landscapes, one ground-truth and one predicted, gradually aligning as an information-cost surface falls between them, polished technical visualization, no text."),
(6,"KL Divergence",r"D_{KL}(P\|Q)=\sum_x P(x)\log\frac{P(x)}{Q(x)}",
"Kullback-Leibler divergence measures how much extra information is required when Q is used to approximate P. It is zero only when the distributions match almost everywhere. Unlike a geometric distance, KL divergence is asymmetric: reversing P and Q changes the question being asked.",
"KL terms appear throughout variational inference, distillation, reinforcement learning, preference optimization, and model regularization. Forward and reverse KL emphasize different failure modes. One often penalizes missing probability mass, while the other can favor concentrating on a dominant mode, so direction matters.",
"Two translucent probability clouds with an asymmetric information flow arrow between them, mismatch rendered as geometric tension, sophisticated mathematical visualization, no text."),
(7,"Mutual Information",r"I(X;Y)=\sum_{x,y}p(x,y)\log\frac{p(x,y)}{p(x)p(y)}",
"Mutual information asks how much knowing one variable reduces uncertainty about another. If X and Y are independent, the joint distribution factorizes and mutual information is zero. Strong dependence raises the value even when the relationship is nonlinear.",
"Representation learning often seeks features that preserve information useful for a target while discarding irrelevant detail. Contrastive objectives, information bottlenecks, feature selection, and multimodal alignment can all be interpreted through mutual information. The difficulty is that exact estimation becomes hard in high dimensions, so practical systems rely on bounds or proxies.",
"Two distant latent manifolds connected by glowing nonlocal information filaments, shared structure emerging despite different coordinates, high-end scientific concept art, no text."),
(8,"Gaussian Distribution",r"p(x)=\frac{1}{\sqrt{2\pi\sigma^2}}e^{-\frac{(x-\mu)^2}{2\sigma^2}}",
"The Gaussian distribution is defined by a mean and variance. The mean locates its center; the variance controls its spread. Its bell shape appears throughout statistics because sums of many weakly dependent effects often approach Gaussian behavior.",
"Gaussian assumptions support noise models, probabilistic embeddings, Kalman-style filtering, weight initialization theory, diffusion processes, and latent-variable models. The distribution is mathematically convenient, but convenience should not be confused with truth: heavy tails, multimodality, and bounded variables can demand different models.",
"A crystalline bell-shaped probability surface floating over a coordinate plane, mean as a central luminous axis and variance as expanding rings, clean scientific render, no text."),
(9,"Multivariate Gaussian",r"p(x)=\frac{e^{-\frac12(x-\mu)^T\Sigma^{-1}(x-\mu)}}{(2\pi)^{d/2}|\Sigma|^{1/2}}",
"The multivariate Gaussian extends the bell curve into many dimensions. Its covariance matrix does two jobs simultaneously: diagonal elements set variance along coordinates, while off-diagonal elements encode linear correlations. Equal-density regions form ellipsoids shaped by the covariance geometry.",
"Multivariate Gaussians are building blocks for Bayesian models, Gaussian processes, latent spaces, uncertainty ellipsoids, and classical state estimators. In advanced AI they also provide a local approximation to complicated distributions, especially when second-order structure is more important than exact global shape.",
"A floating ellipsoidal probability cloud with covariance axes and correlated dimensions bending through latent space, elegant high-dimensional scientific illustration, no text."),
(10,"Jensen-Shannon Divergence",r"JS(P,Q)=\frac12D_{KL}(P\|M)+\frac12D_{KL}(Q\|M),\quad M=\frac{P+Q}{2}",
"Jensen-Shannon divergence symmetrizes and smooths KL divergence by comparing each distribution to their midpoint mixture. It is finite under conditions where KL can explode and treats P versus Q the same as Q versus P.",
"The quantity became especially visible through generative modeling because it describes a stable notion of distributional discrepancy. More broadly, it is useful when model and data distributions need a bounded, symmetric comparison. Its square root is a true metric, which gives the construction stronger geometric behavior than raw KL divergence.",
"Two probability fields flowing into a shared midpoint distribution, then reflecting symmetrically back toward each source, balanced geometric composition, scientific concept art, no text."),
(11,"Affine Transformation",r"z=Wx+b",
"The affine transformation is the linear skeleton of a neural network. The matrix W mixes and rescales input coordinates; the bias b shifts the result. Without a nonlinear activation between affine layers, stacking many such transformations would collapse into a single affine map.",
"Transformers, convolutional networks, multilayer perceptrons, and embedding projections all rely on massive numbers of affine maps. Much of deep learning can be viewed as learning useful coordinate systems through these maps, then introducing nonlinear gates that let the system express curved and compositional decision boundaries.",
"A vector entering a geometric transformation chamber, stretched, rotated, mixed, and shifted into a new coordinate frame, sleek neural-network visual language, no text."),
(12,"ReLU",r"\mathrm{ReLU}(x)=\max(0,x)",
"ReLU keeps positive values and sets negative values to zero. Its piecewise-linear form is computationally cheap and creates networks that are globally nonlinear while remaining locally linear in large regions of input space.",
"ReLU helped make deep networks easier to optimize than saturating activations in many settings. It also creates sparse activations because part of the input range maps exactly to zero. Variants such as GELU, SiLU, and leaky ReLU soften or modify the hard gate, but the underlying idea remains selective nonlinear transmission.",
"A sharp threshold gate in latent space where negative signals vanish and positive signals pass into a luminous linear ramp, architectural technical art, no text."),
(13,"Sigmoid",r"\sigma(x)=\frac{1}{1+e^{-x}}",
"The sigmoid compresses any real number into the interval from zero to one. Near the origin it changes smoothly; at large positive or negative inputs it saturates. This makes it natural for binary probabilities and gates, but saturation can shrink gradients.",
"Sigmoid outputs are common in binary classifiers, independent multilabel heads, recurrent gates, and probabilistic control variables. The function is often best used where a bounded interpretation matters rather than as the universal activation inside every hidden layer.",
"An S-shaped luminous transfer curve passing through a probabilistic gate from zero to one, with saturation zones fading at both extremes, precise scientific graphic, no text."),
(14,"Hyperbolic Tangent",r"\tanh(x)=\frac{e^x-e^{-x}}{e^x+e^{-x}}",
"Tanh maps real values to the interval from minus one to one. Unlike sigmoid, its output is centered around zero, which can make intermediate representations easier to balance. It still saturates for large magnitudes and therefore can suffer vanishing gradients in deep compositions.",
"Tanh remains important in recurrent networks, bounded state updates, classical control systems, and models where signed outputs are useful. Even when newer activations dominate, tanh is a canonical example of how nonlinear squashing changes both representational capacity and gradient flow.",
"A symmetric S-curve spanning negative to positive activation, centered on zero with mirrored saturation wings, elegant mathematical visualization, no text."),
(15,"Softmax",r"\mathrm{softmax}(z_i)=\frac{e^{z_i}}{\sum_j e^{z_j}}",
"Softmax converts arbitrary logits into a normalized categorical distribution. Exponentiation amplifies differences between logits, while division by the sum forces all probabilities to add to one. Adding the same constant to every logit leaves the distribution unchanged.",
"Every autoregressive language model uses a softmax-like normalization to transform vocabulary logits into token probabilities. It also appears in classification and attention. Temperature modifies the sharpness of the same mechanism, making softmax a bridge between raw scores and stochastic decisions.",
"A set of raw vertical energy bars transforming into a normalized probability simplex, one channel rising while all outputs still sum to unity, futuristic scientific art, no text."),
(16,"Multiclass Cross-Entropy Loss",r"\mathcal L=-\sum_i y_i\log\hat y_i",
"Multiclass cross-entropy compares a target class distribution with predicted class probabilities. For one-hot labels, only the correct class contributes directly, so the loss is simply the negative log probability assigned to the target.",
"This objective powers a huge fraction of supervised classification and token prediction. Its logarithmic shape matters: moving a correct prediction from 0.9 to 0.99 helps a little, while assigning 0.001 to the true class is punished severely. That asymmetry drives models away from confident mistakes.",
"A target class beacon and a predicted probability spectrum converging as a logarithmic penalty surface collapses, modern AI training visualization, no text."),
(17,"Mean Squared Error",r"\mathrm{MSE}=\frac1n\sum_i(y_i-\hat y_i)^2",
"Mean squared error averages the squared gap between predictions and targets. Squaring removes sign and makes large errors disproportionately expensive. The loss is smooth and easy to differentiate, which explains its enduring role in regression.",
"MSE appears in regression, reconstruction, distillation, denoising, and diffusion training. It corresponds to maximum likelihood under a Gaussian observation model with fixed variance. Its weakness is sensitivity to outliers: a few large residuals can dominate the objective.",
"Prediction points orbiting a regression curve with squared residual areas glowing more intensely for larger errors, refined technical infographic, no text."),
(18,"Backpropagation",r"\frac{\partial L}{\partial w}=\frac{\partial L}{\partial y}\frac{\partial y}{\partial w}",
"Backpropagation efficiently applies the chain rule through a computational graph. Local derivatives are propagated backward from the loss so that every parameter receives a gradient describing how a small change would affect the final objective.",
"Without backpropagation, training networks with billions of parameters would be computationally impractical. Automatic differentiation systems generalize this idea, storing or recomputing intermediate operations and composing vector-Jacobian products backward through the graph.",
"A deep computational graph illuminated from the loss backward, gradient signals branching through layers toward millions of parameters, cinematic scientific diagram, no text."),
(19,"Gradient Descent",r"\theta_{t+1}=\theta_t-\eta\nabla_\theta L(\theta_t)",
"Gradient descent moves parameters in the direction opposite the local gradient. The learning rate determines step size: too small and progress is slow; too large and the optimizer can oscillate or diverge. The method is local, so the geometry of the loss surface controls the path.",
"Neural training is fundamentally a sequence of such parameter updates, usually modified by minibatching, momentum, adaptive scaling, scheduling, or regularization. Understanding gradient descent means understanding why curvature, noise, normalization, and scale all change learning behavior.",
"A glowing optimization trajectory descending through a folded high-dimensional loss valley, step vectors following local slopes toward a basin, sophisticated mathematical landscape, no text."),
(20,"Chain Rule",r"\frac{\partial f}{\partial x}=\frac{\partial f}{\partial g}\frac{\partial g}{\partial x}",
"The chain rule states how derivatives propagate through compositions. If x influences g and g influences f, then the sensitivity of f to x is the product of the sensitivities along that path. Deep networks are enormous compositions, so this rule is their calculus backbone.",
"Gradient flow, differentiable programming, neural ODEs, meta-learning, and end-to-end optimization all depend on repeated chain-rule composition. Vanishing and exploding gradients emerge because many local derivative factors are multiplied across depth.",
"Nested mathematical transformations connected as a continuous derivative chain, local sensitivities multiplying along a glowing path through deep layers, scientific art, no text."),
(21,"Stochastic Gradient Descent",r"\theta_{t+1}=\theta_t-\eta\nabla_\theta L(\theta_t;x_b)",
"Stochastic gradient descent replaces the exact full-dataset gradient with an estimate from a minibatch. The update is noisy, but drastically cheaper. Repeated noisy steps can still follow the broad direction of the true gradient and sometimes help escape narrow or brittle regions.",
"Nearly all large-scale neural training depends on minibatch gradients. Batch size changes the noise scale, hardware efficiency, and optimization dynamics. SGD is therefore not just an approximation to gradient descent; its stochasticity becomes part of the learning process.",
"A noisy swarm of minibatch gradient arrows collectively drifting down a loss landscape toward a shared basin, energetic but disciplined scientific visualization, no text."),
(22,"Momentum",r"v_t=\beta v_{t-1}+(1-\beta)g_t,\quad \theta_t=\theta_{t-1}-\eta v_t",
"Momentum forms an exponentially smoothed direction from recent gradients. Consistent directions accumulate velocity, while rapidly changing directions tend to cancel. This can speed travel through long valleys and reduce sideways oscillation.",
"Momentum is one of the simplest ways to give optimization memory. Its effect is geometric: the update depends not only on the current slope but also on the recent trajectory. Modern optimizers inherit this idea through moving averages of first moments.",
"A particle carrying velocity through a curved optimization valley, recent gradient arrows blending into a smooth inertial trajectory, elegant dynamical-systems visualization, no text."),
(23,"Adam First Moment",r"m_t=\beta_1m_{t-1}+(1-\beta_1)g_t",
"Adam's first moment is an exponential moving average of gradients. It estimates the persistent direction of recent optimization pressure while filtering high-frequency minibatch noise.",
"The first moment behaves like momentum, but Adam combines it with a second moment that rescales updates coordinate by coordinate. In very large models this smoothing helps produce stable progress across parameters whose raw gradients differ substantially in scale.",
"A jagged gradient signal entering an exponential smoothing filter and emerging as a steady directional field, modern optimizer infographic, no text."),
(24,"Adam Second Moment",r"v_t=\beta_2v_{t-1}+(1-\beta_2)g_t^2",
"Adam's second moment tracks an exponential average of squared gradients. Because the square removes sign, the quantity estimates recent gradient magnitude rather than direction. Large values indicate coordinates experiencing consistently large updates.",
"Dividing by the square root of this moment normalizes step sizes, allowing parameters with different gradient scales to learn at more comparable effective rates. The stabilizing constant epsilon prevents division by zero and matters in low-precision numerical regimes.",
"A gradient magnitude signal squared and accumulated into an adaptive scale field, high-energy coordinates compressed while quiet coordinates remain visible, scientific graphic, no text."),
(25,"Adam Update",r"\theta_t=\theta_{t-1}-\eta\frac{\hat m_t}{\sqrt{\hat v_t}+\epsilon}",
"The Adam update combines a direction estimate from the first moment with scale normalization from the second. Bias-corrected moments compensate for initialization near zero, especially during early optimization steps.",
"Adam and related optimizers are standard tools for transformer training because they tolerate heterogeneous gradient scales and noisy minibatches. They do not eliminate the need for good learning-rate schedules, clipping, initialization, or regularization; they change the geometry of the step.",
"A multidimensional optimizer vector being directionally smoothed and scale-normalized before entering a parameter landscape, premium scientific visualization, no text."),
(26,"L2 Regularization",r"L_{reg}=L+\lambda\|\theta\|_2^2",
"L2 regularization adds a penalty proportional to squared parameter magnitude. Large weights become more expensive, encouraging solutions with smaller overall norm. The penalty is smooth and spreads pressure across many parameters.",
"Regularization can improve generalization when model capacity exceeds the information available in the data. In neural networks, explicit L2 penalties and optimizer-level weight decay are closely related but not always identical, especially for adaptive optimizers.",
"A parameter vector being pulled inward toward a smooth spherical norm boundary while preserving task fit, clean geometric regularization illustration, no text."),
(27,"L1 Regularization",r"L_{reg}=L+\lambda\|\theta\|_1",
"L1 regularization penalizes the sum of absolute parameter magnitudes. Its sharp geometry at zero encourages some parameters to become exactly or nearly zero, producing sparse solutions.",
"Sparsity can support feature selection, compression, interpretable linear models, or structured pruning. In massive neural networks, practical sparsity often requires specialized methods, but the L1 objective remains the canonical mathematical route from regularization to zeros.",
"A high-dimensional parameter cloud collapsing onto sparse coordinate axes and sharp diamond-shaped norm contours, precise mathematical illustration, no text."),
(28,"Newton's Method",r"\theta_{t+1}=\theta_t-H^{-1}\nabla L",
"Newton's method uses both the gradient and the Hessian, a matrix of second derivatives. The Hessian estimates local curvature, allowing the optimizer to rescale directions according to how sharply the loss bends.",
"Exact Newton steps are usually too expensive for modern deep networks because the Hessian is enormous. Yet the principle survives in quasi-Newton methods, natural-gradient ideas, curvature approximations, second-order diagnostics, and preconditioners.",
"A curved loss surface with local Hessian geometry reshaping a gradient step into a direct curvature-aware jump toward the optimum, advanced mathematical visualization, no text."),
(29,"Scaled Dot-Product Attention",r"\mathrm{Attention}(Q,K,V)=\mathrm{softmax}\!\left(\frac{QK^T}{\sqrt{d_k}}\right)V",
"Attention compares queries with keys through dot products, scales the scores, normalizes them with softmax, and uses the resulting weights to mix values. The square-root scaling prevents dot products from growing too large as key dimension increases.",
"This equation is the central routing mechanism of the transformer. It lets every token construct a context-dependent weighted view of other tokens. What a model retrieves is therefore not stored in one fixed location; it is dynamically assembled from relationships among query, key, and value representations.",
"A transformer token projecting query beams across a field of keys, softmax weights illuminating selected value streams that recombine into context, cinematic AI visualization, no text."),
(30,"Multi-Head Attention",r"\mathrm{MHA}(Q,K,V)=\mathrm{Concat}(head_1,\ldots,head_h)W^O",
"Multi-head attention runs several attention mechanisms in parallel, concatenates their outputs, and projects the result back into the model dimension. Each head has its own learned projections, so heads can specialize in different relational patterns.",
"Parallel heads increase representational flexibility: one head may track local syntax, another long-distance dependencies, another formatting or positional structure. Head behavior is not guaranteed to be cleanly interpretable, but the architecture creates multiple simultaneous channels for context routing.",
"Several distinct attention beams operating in parallel over the same token field, then merging through a final projection into one coherent representation, polished technical art, no text."),
(31,"Attention Head",r"head_i=\mathrm{Attention}(QW_i^Q,KW_i^K,VW_i^V)",
"An attention head first projects queries, keys, and values into head-specific subspaces. Attention is then computed inside that learned coordinate system. The projections determine which features are visible to that head before any token-to-token comparison occurs.",
"Thinking of a head as only an attention matrix misses half the mechanism. The learned Q, K, and V projections define what similarity means and what information is carried forward. Head specialization therefore emerges from both routing weights and representational subspaces.",
"One attention head shown as three learned projection lenses for query, key, and value, converging into a focused relational map, high-detail scientific diagram, no text."),
(32,"Transformer Residual Connection",r"x'=x+\mathrm{Attention}(x)",
"A residual connection adds a module's transformation back to its input. Rather than forcing each layer to replace the representation, the layer can learn an incremental correction. This creates a persistent information pathway through depth.",
"Residual streams are fundamental to deep transformers because they improve gradient flow and allow many modules to write into a shared evolving representation. Modern block ordering can be pre-normalized or post-normalized, but residual addition remains the backbone connecting layers.",
"A continuous residual information stream flowing through many transformer layers while attention modules inject structured corrections into it, elegant architecture visualization, no text."),
(33,"Layer Normalization",r"\mathrm{LN}(x)=\gamma\frac{x-\mu}{\sqrt{\sigma^2+\epsilon}}+\beta",
"Layer normalization centers and scales the features of an individual example, then restores learnable scale and offset through gamma and beta. Unlike batch normalization, it does not require statistics across different examples in a minibatch.",
"Transformers rely heavily on layer normalization or close variants such as RMSNorm. Normalization controls activation scale, stabilizes deep residual stacks, and changes the effective geometry seen by attention and feed-forward blocks.",
"A chaotic feature vector entering a normalization field and emerging centered and rescaled, followed by learnable stretching and shifting, clean technical illustration, no text."),
(34,"Transformer Feed-Forward Network",r"\mathrm{FFN}(x)=W_2\,\sigma(W_1x+b_1)+b_2",
"The transformer feed-forward network applies an affine expansion, a nonlinearity, and a projection back to the model dimension. It acts independently at each token position, unlike attention, which mixes information across positions.",
"A useful mental model is that attention routes information between tokens while the FFN performs nonlinear feature transformation within each token. In many large language models, these feed-forward blocks hold a substantial share of the parameters and computational cost.",
"A token representation expanding into a wide nonlinear feature chamber and compressing back into the residual stream, sophisticated transformer internals visualization, no text."),
(35,"Autoregressive Factorization",r"P(x_{1:T})=\prod_{t=1}^{T}P(x_t\mid x_{<t})",
"Autoregressive factorization writes the probability of an entire sequence as a product of next-step conditional probabilities. The chain rule of probability guarantees this factorization; modeling chooses how each conditional distribution is represented.",
"Language models train and generate under this decomposition. At each position the model predicts a distribution conditioned on preceding tokens, then generation repeatedly samples or selects one token and feeds it back as context. Sequence intelligence emerges from iterating a local next-token rule.",
"A sequence of tokens unfolding through time, each new symbol branching from a conditional probability field conditioned on the entire prior path, cinematic AI visualization, no text."),
(36,"Language-Model Loss",r"L=-\sum_{t=1}^{T}\log P(x_t\mid x_{<t})",
"The language-model objective sums the negative log probability assigned to the correct next token at every position. Minimizing it is equivalent to maximizing the likelihood of the observed training sequences under the autoregressive model.",
"This deceptively compact loss scales to enormous datasets and model sizes. It does not explicitly instruct the model to reason, summarize, code, or converse; those capabilities can emerge because accurate next-token prediction requires capturing increasingly rich structure in the data distribution.",
"A long token stream passing through a predictive field where each correct next token lowers a cumulative log-loss energy trace, refined AI training artwork, no text."),
(37,"Causal Attention Mask",r"A_{ij}=\begin{cases}0,&j\le i\\-\infty,&j>i\end{cases}",
"The causal mask prevents a position from attending to future positions during autoregressive training. Adding negative infinity before softmax forces disallowed attention weights to zero, preserving the same information constraint used during generation.",
"Without this mask, a language model could cheat by directly reading future tokens while being trained to predict them. The mask therefore turns a parallel training computation into a valid simulation of sequential prediction.",
"A triangular attention matrix with the future region sealed behind an impenetrable boundary while the past remains illuminated and accessible, crisp scientific diagram, no text."),
(38,"Rotary Position Embedding",r"\begin{pmatrix}x'_{2i}\\x'_{2i+1}\end{pmatrix}=\begin{pmatrix}\cos\theta_i&-\sin\theta_i\\\sin\theta_i&\cos\theta_i\end{pmatrix}\begin{pmatrix}x_{2i}\\x_{2i+1}\end{pmatrix}",
"Rotary position embeddings encode position by rotating pairs of feature coordinates by position-dependent angles. Relative displacement between positions becomes embedded in the phase difference between their rotated query and key components.",
"RoPE is widely used in modern language models because it integrates positional structure directly into attention geometry. Extensions that rescale or interpolate its frequencies are also used to support contexts longer than those seen during original training.",
"Pairs of latent coordinates rotating around concentric phase circles as token position advances, relative angles forming structured attention geometry, elegant mathematical art, no text."),
(39,"Evidence Lower Bound",r"\log p(x)\ge \mathbb E_{q(z\mid x)}[\log p(x\mid z)]-D_{KL}(q(z\mid x)\|p(z))",
"The evidence lower bound replaces an often-intractable marginal likelihood with a tractable objective. Its first term rewards latent codes that reconstruct or explain the observation; its KL term keeps the approximate posterior close to a chosen prior.",
"ELBO optimization powers variational inference and variational autoencoders. The equation exposes a central tradeoff in representation learning: preserve enough information in z to model the data while maintaining a latent distribution that remains regular and sampleable.",
"A latent-variable model balancing reconstruction fidelity against a smooth prior geometry on opposite sides of a lower-bound scale, sophisticated generative-model visualization, no text."),
(40,"VAE Objective",r"L_{VAE}=-\mathbb E_{q(z\mid x)}[\log p(x\mid z)]+D_{KL}(q(z\mid x)\|p(z))",
"The VAE loss is the negative form of the ELBO: reconstruction error plus a KL regularizer. The encoder maps data to a distribution over latent variables; the decoder reconstructs data from samples drawn from that latent distribution.",
"Unlike a deterministic autoencoder, a VAE explicitly shapes a probabilistic latent space. That enables interpolation and generation, but strong regularization can also cause posterior collapse, where the decoder ignores the latent variable because using it is not worth the KL cost.",
"An encoder transforming data into a smooth probabilistic latent cloud, samples crossing a bottleneck into a decoder, reconstruction and regularity in visual balance, no text."),
(41,"GAN Discriminator Objective",r"\max_D\;\mathbb E_{x\sim p_{data}}\log D(x)+\mathbb E_{z\sim p(z)}\log(1-D(G(z)))",
"The discriminator is trained to assign high scores to real data and low scores to generated samples. Its objective turns generative learning into a competitive game: distinguish reality from synthesis as accurately as possible.",
"A strong discriminator provides the generator with a learned training signal that does not require an explicit likelihood. The adversarial game can produce sharp samples, but it is also vulnerable to instability, vanishing gradients, and mode collapse when the two players become unbalanced.",
"A discriminator boundary separating real and generated sample clouds while both distributions evolve in response, adversarial game rendered as dynamic geometry, no text."),
(42,"GAN Generator Objective",r"\min_G\;\mathbb E_{z\sim p(z)}[\log(1-D(G(z)))]",
"The generator transforms noise into synthetic samples and adjusts itself according to the discriminator's judgment. In the original minimax formulation it tries to minimize the probability that generated samples are detected as fake.",
"Practical GAN training often uses a non-saturating generator loss for stronger gradients, but the core idea is unchanged: a generator learns indirectly through an adversary. This creates an adaptive objective whose shape changes as the discriminator improves.",
"A generator morphing latent noise into structured samples while crossing an adversarial decision boundary that shifts in response, high-end AI concept art, no text."),
(43,"Diffusion Forward Process",r"q(x_t\mid x_{t-1})=\mathcal N(\sqrt{1-\beta_t}\,x_{t-1},\beta_t I)",
"The forward diffusion process gradually corrupts data with Gaussian noise. At each step, part of the previous signal is retained and fresh noise is added according to a schedule beta_t. After enough steps, structured data becomes close to simple noise.",
"The forward process is deliberately easy; the intelligence is learned in reversing it. By creating a known corruption path, diffusion models turn generation into a sequence of denoising problems rather than a single jump from noise to data.",
"A detailed image dissolving through successive layers of Gaussian noise until only an isotropic cloud remains, smooth time progression, cinematic generative-model visualization, no text."),
(44,"Closed-Form Diffusion Noising",r"x_t=\sqrt{\bar\alpha_t}x_0+\sqrt{1-\bar\alpha_t}\,\epsilon",
"The closed-form noising equation allows a model to sample any diffusion timestep directly from clean data. The coefficient on x_0 controls retained signal, while the coefficient on epsilon controls injected noise.",
"This shortcut is crucial for efficient training: there is no need to simulate every previous diffusion step before producing x_t. A random timestep can be selected, noised in one operation, and used to train the denoiser.",
"A clean signal and pure noise mixed by two complementary square-root coefficients into a family of intermediate states across time, elegant scientific visualization, no text."),
(45,"Diffusion Denoising Objective",r"L=\mathbb E_{t,x_0,\epsilon}\left[\|\epsilon-\epsilon_\theta(x_t,t)\|^2\right]",
"A common diffusion objective trains the network to predict the exact noise added to a corrupted sample. The error is measured with a squared norm across randomly selected examples, timesteps, and noise draws.",
"Noise prediction is attractive because the target is known exactly during training. Once the network can estimate the noise component at many corruption levels, a sampler can repeatedly remove predicted noise and reconstruct structured data from an initially random state.",
"A neural denoiser extracting a precise noise vector from a corrupted state, repeated stages revealing structured data from randomness, cinematic generative AI art, no text."),
(46,"Expected Discounted Return",r"G_t=\sum_{k=0}^{\infty}\gamma^kR_{t+k+1}",
"The return adds future rewards while discounting distant outcomes by powers of gamma. A gamma near zero emphasizes immediate rewards; a gamma near one gives long-horizon consequences more influence.",
"Reinforcement-learning agents optimize behavior through estimates of return. Discounting controls effective planning horizon and keeps infinite sums mathematically manageable. The choice of reward function and gamma together defines what the agent is actually incentivized to value over time.",
"A branching decision timeline where future rewards glow with exponentially fading intensity as distance from the present increases, elegant reinforcement-learning visualization, no text."),
(47,"Bellman Equation",r"V^\pi(s)=\mathbb E_\pi[R_{t+1}+\gamma V^\pi(S_{t+1})\mid S_t=s]",
"The Bellman equation expresses a value recursively: the worth of a state equals expected immediate reward plus the discounted value of the next state. This turns a long-horizon problem into a local consistency condition.",
"Dynamic programming, temporal-difference learning, actor-critic methods, and many planning algorithms depend on Bellman structure. A value function is correct when its predictions agree with the one-step reward-plus-next-value targets generated by the environment and policy.",
"A state-value landscape recursively reflecting immediate reward and the value of future states, nested decision geometry converging to a fixed point, scientific art, no text."),
(48,"Q-Learning Update",r"Q(s,a)\leftarrow Q(s,a)+\alpha[r+\gamma\max_{a'}Q(s',a')-Q(s,a)]",
"Q-learning updates an action value toward a target built from observed reward plus the best estimated next-state action value. The bracketed difference is the temporal-difference error: a measure of surprise relative to the current estimate.",
"Because the target uses a max over next actions, Q-learning is off-policy: it can learn about a greedy policy while data comes from a more exploratory behavior policy. Deep Q-networks replace the table of Q-values with a neural approximator and add stabilization machinery.",
"A state-action value grid receiving temporal-difference correction pulses, values propagating backward from rewarding future states, advanced reinforcement-learning visualization, no text."),
(49,"Policy Gradient",r"\nabla_\theta J(\theta)=\mathbb E_{\pi_\theta}[\nabla_\theta\log\pi_\theta(a\mid s)G_t]",
"The policy-gradient theorem adjusts policy parameters directly. Actions that produced high returns become more likely because their log-probability gradients are reinforced; low-return actions are pushed in the opposite direction when advantages or centered returns are used.",
"Policy gradients support continuous actions and complex stochastic policies without requiring explicit maximization over every possible action. Variance reduction is essential in practice, which is why baselines, value critics, generalized advantage estimation, and clipping are common companions.",
"A stochastic policy distribution deforming toward high-return actions under gradient pressure, probability mass flowing across an action landscape, cinematic RL visualization, no text."),
(50,"PPO Clipped Objective",r"L^{CLIP}(\theta)=\mathbb E_t\left[\min\!\left(r_tA_t,\mathrm{clip}(r_t,1-\epsilon,1+\epsilon)A_t\right)\right]",
"Proximal Policy Optimization limits how much the new policy can benefit from moving too far from the behavior policy in one update. The probability ratio r_t measures policy change; clipping creates a plateau once the change exceeds a trusted interval.",
"PPO became popular because it approximates trust-region behavior with a relatively simple first-order objective. It is used in simulated control and has also played a major role in reinforcement learning from human feedback, where stable policy updates are especially important.",
"A policy-update curve entering a protected clipping corridor, aggressive probability-ratio movement flattened beyond trusted boundaries while advantage guides direction, polished scientific art, no text."),
]

# category labels
cats={range(1,11):'Probability & Information',range(11,21):'Neural Foundations',range(21,29):'Optimization',range(29,39):'Transformers & Sequence Models',range(39,46):'Generative Models',range(46,51):'Reinforcement Learning'}
def category(i):
    for r,n in cats.items():
        if i in r:return n

# Writing modulation based on entropy; visible text never names the mechanism.
openers_low=["The useful intuition is concrete:","Read this equation operationally:","At its core:"]
openers_mid=["A useful way to read it is this:","The deeper pattern is compact:","One practical interpretation is:"]
openers_high=["Seen geometrically, the equation says:","Viewed as an information flow, it says:","At a systems level, the relation says:"]

def opener(i):
    e=float(entrows[i]['mean_entanglement_entropy'])
    choices=openers_low if e<0.4 else openers_mid if e<0.75 else openers_high
    return choices[(i*7)%len(choices)]

# --- figures ---
def save_formula(i, eq):
    fig=plt.figure(figsize=(7,1.05),dpi=180)
    fig.patch.set_alpha(0)
    ax=fig.add_axes([0,0,1,1]); ax.axis('off')
    ax.text(0.5,0.5,'$'+eq+'$',ha='center',va='center',fontsize=20)
    p=ASSETS/f'formula_{i:03d}.png'; fig.savefig(p,transparent=True,bbox_inches='tight',pad_inches=0.12); plt.close(fig); return p

def clean(ax,xlab=None,ylab=None):
    ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False)
    ax.grid(True,alpha=.18,linewidth=.6)
    ax.tick_params(labelsize=7)
    if xlab: ax.set_xlabel(xlab,fontsize=7)
    if ylab: ax.set_ylabel(ylab,fontsize=7)

def save_chart(i):
    fig,ax=plt.subplots(figsize=(6.3,2.05),dpi=180)
    x=np.linspace(-4,4,240)
    if i==1:
        lr=np.logspace(-2,2,240); prior=.2; post=(lr*prior)/(lr*prior+1-prior); ax.semilogx(lr,post); clean(ax,'likelihood ratio','posterior')
    elif i==2:
        data=np.array([-1.1,-.6,-.1,.2,.8,1.0]); mu=np.linspace(-2,2,240); ll=np.array([-0.5*np.sum((data-m)**2) for m in mu]); ax.plot(mu,ll); clean(ax,'parameter μ','log-likelihood')
    elif i==3:
        th=np.linspace(-2,2,240); lik=np.exp(-2*(th-.45)**2); ax.plot(th,lik); ax.axvline(.45,ls='--',lw=1); clean(ax,'θ','likelihood')
    elif i==4:
        p=np.linspace(.001,.999,240); h=-(p*np.log2(p)+(1-p)*np.log2(1-p)); ax.plot(p,h); clean(ax,'P(X=1)','entropy (bits)')
    elif i==5:
        q=np.linspace(.01,.99,240); ax.plot(q,-np.log(q)); clean(ax,'predicted probability of truth','cross-entropy')
    elif i==6:
        q=np.linspace(.02,.98,240); p=.72; d=p*np.log(p/q)+(1-p)*np.log((1-p)/(1-q)); ax.plot(q,d); clean(ax,'Q probability','KL(P||Q)')
    elif i==7:
        rho=np.linspace(-.98,.98,240); mi=-.5*np.log(1-rho**2); ax.plot(rho,mi); clean(ax,'correlation proxy','mutual information')
    elif i==8:
        for s in [.6,1.0,1.5]: ax.plot(x,np.exp(-x*x/(2*s*s))/(np.sqrt(2*np.pi)*s))
        clean(ax,'x','density')
    elif i==9:
        xx=np.linspace(-3,3,220); ax.plot(xx,np.exp(-.5*xx**2)); ax.plot(xx,np.exp(-.5*(xx/1.7)**2)/1.7); clean(ax,'principal axis','density slice')
    elif i==10:
        q=np.linspace(.01,.99,240); p=.75; m=(p+q)/2; js=.5*(p*np.log(p/m)+(1-p)*np.log((1-p)/(1-m)))+.5*(q*np.log(q/m)+(1-q)*np.log((1-q)/(1-m))); ax.plot(q,js); clean(ax,'Q probability','JS divergence')
    elif i==11:
        ax.plot(x,1.4*x+.6); clean(ax,'x','Wx+b')
    elif i==12:
        ax.plot(x,np.maximum(0,x)); clean(ax,'x','ReLU(x)')
    elif i==13:
        ax.plot(x,1/(1+np.exp(-x))); clean(ax,'x','σ(x)')
    elif i==14:
        ax.plot(x,np.tanh(x)); clean(ax,'x','tanh(x)')
    elif i==15:
        d=np.linspace(-5,5,240); p=1/(1+np.exp(-d)); ax.plot(d,p); clean(ax,'logit advantage','softmax probability')
    elif i==16:
        p=np.linspace(.01,.999,240); ax.plot(p,-np.log(p)); clean(ax,'correct-class probability','loss')
    elif i==17:
        e=np.linspace(-3,3,240); ax.plot(e,e**2); clean(ax,'prediction error','squared error')
    elif i==18:
        depth=np.arange(1,13); a=.82; ax.plot(depth,a**depth,marker='o'); clean(ax,'chain depth','gradient product')
    elif i==19:
        th=np.linspace(-3,3,240); ax.plot(th,th**2); pts=[2.7];
        for _ in range(8): pts.append(pts[-1]-.18*(2*pts[-1]))
        ax.plot(pts,np.array(pts)**2,marker='o'); clean(ax,'θ','loss')
    elif i==20:
        xx=np.linspace(-2,2,240); ax.plot(xx,np.cos(xx)*2*xx); clean(ax,'x','composed derivative')
    elif i==21:
        rng=np.random.default_rng(21); steps=70; y=[3.0]
        for t in range(steps-1): y.append(y[-1]-.08*(2*y[-1]+rng.normal(0,.8)))
        ax.plot(y); clean(ax,'minibatch step','parameter')
    elif i==22:
        t=np.arange(60); raw=np.sin(t/5)*np.exp(-t/35); mom=np.convolve(raw,np.ones(8)/8,mode='same'); ax.plot(t,raw,alpha=.6); ax.plot(t,mom,lw=2); clean(ax,'step','gradient / momentum')
    elif i==23:
        t=np.arange(60); g=np.where(t<15,0,1.0); m=np.zeros_like(g,float)
        for k in range(1,len(t)):m[k]=.9*m[k-1]+.1*g[k]
        ax.plot(t,g,alpha=.5); ax.plot(t,m,lw=2); clean(ax,'step','first moment')
    elif i==24:
        t=np.arange(60); g=np.where(t<18,.2,1.2); v=np.zeros_like(g,float)
        for k in range(1,len(t)):v[k]=.95*v[k-1]+.05*g[k]**2
        ax.plot(t,g**2,alpha=.5); ax.plot(t,v,lw=2); clean(ax,'step','second moment')
    elif i==25:
        g=np.linspace(.01,3,240); update=g/(np.sqrt(g*g)+.1); ax.plot(g,update); clean(ax,'gradient scale','normalized update')
    elif i==26:
        w=np.linspace(-3,3,240); ax.plot(w,w*w); clean(ax,'weight','L2 penalty')
    elif i==27:
        w=np.linspace(-3,3,240); ax.plot(w,np.abs(w)); clean(ax,'weight','L1 penalty')
    elif i==28:
        th=np.linspace(-3,3,240); ax.plot(th,(th-.8)**2+.15*(th-.8)**4); pts=[2.8,1.55,1.02,.84,.801]; ax.plot(pts,[(p-.8)**2+.15*(p-.8)**4 for p in pts],marker='o'); clean(ax,'θ','loss')
    elif i==29:
        s=np.linspace(-4,4,240); ax.plot(s,1/(1+np.exp(-s))); clean(ax,'scaled dot-product score','attention weight')
    elif i==30:
        pos=np.arange(20)
        for h in range(4): ax.plot(pos,np.exp(-((pos-(4+4*h))**2)/(2*(1.5+h*.3)**2)))
        clean(ax,'token position','head response')
    elif i==31:
        pos=np.arange(24); ax.plot(pos,np.exp(-((pos-15)**2)/8)); clean(ax,'projected key position','head attention')
    elif i==32:
        xx=np.linspace(-3,3,240); ax.plot(xx,xx,ls='--',alpha=.7); ax.plot(xx,xx+.35*np.sin(2*xx)); clean(ax,'input residual','updated residual')
    elif i==33:
        vals=np.array([-3,-1.2,-.7,.1,.5,2.7,5.1]); norm=(vals-vals.mean())/vals.std(); ax.plot(vals,marker='o'); ax.plot(norm,marker='o'); clean(ax,'feature index','value')
    elif i==34:
        xx=np.linspace(-3,3,240); ax.plot(xx,.6*np.tanh(1.5*xx+0.5)-.35*np.tanh(.7*xx-1)); clean(ax,'token feature','FFN output')
    elif i==35:
        t=np.arange(1,30); p=.92**t; ax.plot(t,p); clean(ax,'sequence length','joint probability proxy')
    elif i==36:
        p=np.linspace(.01,.999,240); ax.plot(p,-np.log(p)); clean(ax,'next-token probability','token loss')
    elif i==37:
        n=14; mask=np.tril(np.ones((n,n))); ax.imshow(mask,aspect='auto',origin='upper'); ax.set_xlabel('key position',fontsize=7); ax.set_ylabel('query position',fontsize=7); ax.tick_params(labelsize=6)
    elif i==38:
        a=np.linspace(0,2*np.pi,80); ax.plot(np.cos(a),np.sin(a),alpha=.35); pts=np.linspace(0,1.8,10); ax.scatter(np.cos(pts),np.sin(pts),s=14); ax.set_aspect('equal'); clean(ax,'rotated dim 1','rotated dim 2')
    elif i==39:
        z=np.linspace(0,1,240); recon=(1-z)**2; kl=z**2*.6; ax.plot(z,recon); ax.plot(z,kl); ax.plot(z,recon+kl,lw=2); clean(ax,'latent regularization','objective terms')
    elif i==40:
        z=np.linspace(0,1,240); ax.plot(z,(1-z)**2+.6*z*z); clean(ax,'regularization strength','VAE loss')
    elif i==41:
        D=np.linspace(.01,.99,240); obj=np.log(D)+np.log(1-D); ax.plot(D,obj); clean(ax,'discriminator confidence','balanced objective')
    elif i==42:
        D=np.linspace(.01,.99,240); ax.plot(D,np.log(1-D)); clean(ax,'D(G(z))','generator minimax term')
    elif i==43:
        t=np.linspace(0,1,240); signal=np.sqrt(1-.92*t); noise=np.sqrt(.92*t); ax.plot(t,signal); ax.plot(t,noise); clean(ax,'diffusion time','coefficient')
    elif i==44:
        t=np.linspace(0,1,240); ax.plot(t,np.sqrt(1-t)); ax.plot(t,np.sqrt(t)); clean(ax,'normalized t','signal / noise mixing')
    elif i==45:
        t=np.arange(1,101); ax.plot(t,1/(1+.05*t)+.03); clean(ax,'training progress','noise-prediction loss')
    elif i==46:
        k=np.arange(0,40); ax.plot(k,.95**k); ax.plot(k,.8**k); clean(ax,'future step','discount weight')
    elif i==47:
        it=np.arange(25); ax.plot(it,1-np.exp(-it/5)); clean(ax,'Bellman iteration','value estimate')
    elif i==48:
        it=np.arange(45); q=1-np.exp(-it/8)+.08*np.sin(it/2)*np.exp(-it/18); ax.plot(it,q); clean(ax,'update','Q estimate')
    elif i==49:
        th=np.linspace(-4,4,240); reward=np.exp(-.5*(th-1.2)**2); ax.plot(th,reward); ax.annotate('',xy=(.7,np.exp(-.5*(.7-1.2)**2)),xytext=(-.2,np.exp(-.5*(-.2-1.2)**2)),arrowprops={'arrowstyle':'->'}); clean(ax,'policy parameter','expected return')
    elif i==50:
        r=np.linspace(.5,1.5,240); A=1.; eps=.2; unclipped=r*A; clipped=np.clip(r,1-eps,1+eps)*A; ax.plot(r,np.minimum(unclipped,clipped)); ax.axvline(1-eps,ls='--',lw=1); ax.axvline(1+eps,ls='--',lw=1); clean(ax,'probability ratio r','clipped surrogate')
    fig.tight_layout(pad=.55)
    p=ASSETS/f'chart_{i:03d}.png'; fig.savefig(p,bbox_inches='tight'); plt.close(fig); return p

for i,title,eq,*_ in PAGES:
    save_formula(i,eq); save_chart(i)

# --- docx helpers ---
def set_cell_shading(cell, fill='F3F4F6'):
    tcPr=cell._tc.get_or_add_tcPr(); shd=OxmlElement('w:shd'); shd.set(qn('w:fill'),fill); tcPr.append(shd)

def set_repeat_table_borders_none(table):
    tblPr=table._tbl.tblPr
    borders=OxmlElement('w:tblBorders')
    for edge in ('top','left','bottom','right','insideH','insideV'):
        el=OxmlElement(f'w:{edge}'); el.set(qn('w:val'),'nil'); borders.append(el)
    tblPr.append(borders)

def add_text(doc,text,size=9.1,bold=False,italic=False,space_after=3,align=None):
    p=doc.add_paragraph(); p.paragraph_format.space_after=Pt(space_after); p.paragraph_format.line_spacing=1.04
    if align is not None:p.alignment=align
    r=p.add_run(text); r.bold=bold; r.italic=italic; r.font.size=Pt(size); r.font.name='Aptos'
    return p

D=Document()
sec=D.sections[0]
sec.page_width=Inches(6); sec.page_height=Inches(9)
sec.top_margin=Inches(.42); sec.bottom_margin=Inches(.42); sec.left_margin=Inches(.52); sec.right_margin=Inches(.52)
sec.header_distance=Inches(.18); sec.footer_distance=Inches(.2)

styles=D.styles
styles['Normal'].font.name='Aptos'; styles['Normal'].font.size=Pt(9.1)

# header/footer
hp=sec.header.paragraphs[0]; hp.alignment=WD_ALIGN_PARAGRAPH.CENTER
hr=hp.add_run('THE EQUATION ATLAS OF ADVANCED AI  •  PAGES 1–50'); hr.font.name='Aptos'; hr.font.size=Pt(6.8); hr.font.bold=True
fp=sec.footer.paragraphs[0]; fp.alignment=WD_ALIGN_PARAGRAPH.CENTER
# PAGE field
run=fp.add_run(); fld=OxmlElement('w:fldSimple'); fld.set(qn('w:instr'),'PAGE'); run._r.addnext(fld)

for idx,(i,title,eq,meaning,ai,prompt) in enumerate(PAGES):
    # small category line
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(0); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run(category(i).upper()); r.font.size=Pt(6.7); r.font.bold=True; r.font.name='Aptos';
    p2=D.add_paragraph(); p2.paragraph_format.space_after=Pt(1); p2.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p2.add_run(f'{i:02d}  ·  {title}'); r.font.size=Pt(14.2); r.font.bold=True; r.font.name='Aptos Display'
    # formula
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(2); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(ASSETS/f'formula_{i:03d}.png'),width=Inches(4.55))

    # prose
    e=float(entrows[i]['mean_entanglement_entropy'])
    size=8.85 if e>0.78 else 9.0 if e>0.45 else 9.15
    add_text(D,opener(i)+' '+meaning,size=size,space_after=3)
    add_text(D,ai,size=size,space_after=3)

    # chart
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(1); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(ASSETS/f'chart_{i:03d}.png'),width=Inches(4.72))
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(2); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run('Concept graph — a compact visual intuition, not a benchmark result.'); r.font.size=Pt(6.5); r.font.italic=True; r.font.name='Aptos'

    # image prompt box
    tbl=D.add_table(rows=1,cols=1); tbl.alignment=WD_TABLE_ALIGNMENT.CENTER; tbl.autofit=False; tbl.columns[0].width=Inches(4.75)
    set_repeat_table_borders_none(tbl); cell=tbl.cell(0,0); cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER; set_cell_shading(cell)
    cell.margin_top=Inches(.05); cell.margin_bottom=Inches(.05)
    pp=cell.paragraphs[0]; pp.paragraph_format.space_after=Pt(0); pp.paragraph_format.line_spacing=1.0
    rr=pp.add_run('IMAGE PROMPT  '); rr.bold=True; rr.font.size=Pt(6.5); rr.font.name='Aptos'
    rr=pp.add_run(prompt); rr.font.size=Pt(6.45); rr.font.name='Aptos'; rr.italic=True

    if i==1:
        p=D.add_paragraph(); p.paragraph_format.space_before=Pt(2); p.paragraph_format.space_after=Pt(0)
        r=p.add_run('Series note: equations 1–100 summarize established or widely used mathematical ideas; later volumes clearly distinguish speculative constructions.'); r.font.size=Pt(6.1); r.font.italic=True; r.font.name='Aptos'
    if idx < len(PAGES)-1:
        D.add_page_break()

# core props
D.core_properties.title='The Equation Atlas of Advanced AI — Pages 1–50'
D.core_properties.subject='A 500-equation advanced AI fieldbook, first fifty pages'
D.core_properties.comments='Prepared as a Kindle/KDP-oriented manuscript segment.'
D.save(OUT)
print(OUT)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
ls -lh /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx
Matplotlib is building the font cache; this may take a moment.
Traceback (most recent call last):
  File "/mnt/data/equation_atlas_1_50/build_book.py", line 374, in <module>
    save_formula(i,eq); save_chart(i)
    ~~~~~~~~~~~~^^^^^^
  File "/mnt/data/equation_atlas_1_50/build_book.py", line 247, in save_formula
    p=ASSETS/f'formula_{i:03d}.png'; fig.savefig(p,transparent=True,bbox_inches='tight',pad_inches=0.12); plt.close(fig); return p
                                     ~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/figure.py", line 3490, in savefig
    self.canvas.print_figure(fname, **kwargs)
    ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/backend_bases.py", line 2157, in print_figure
    self.figure.draw(renderer)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 94, in draw_wrapper
    result = draw(artist, renderer, *args, **kwargs)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/figure.py", line 3257, in draw
    mimage._draw_list_compositing_images(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, self, artists, self.suppressComposite)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/image.py", line 134, in _draw_list_compositing_images
    a.draw(renderer)
    ~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/axes/_base.py", line 3226, in draw
    mimage._draw_list_compositing_images(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, self, artists, self.get_figure(root=True).suppressComposite)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/image.py", line 134, in _draw_list_compositing_images
    a.draw(renderer)
    ~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 752, in draw
    bbox, info, descent = self._get_layout(renderer)
                          ~~~~~~~~~~~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 382, in _get_layout
    w, h, d = _get_text_metrics_with_cache(
              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, clean_line, self._fontproperties,
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        ismath=ismath, dpi=self.get_figure(root=True).dpi)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 69, in _get_text_metrics_with_cache
    return _get_text_metrics_with_cache_impl(
        weakref.ref(renderer), text, fontprop.copy(), ismath, dpi)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 77, in _get_text_metrics_with_cache_impl
    return renderer_ref().get_text_width_height_descent(text, fontprop, ismath)
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/backends/backend_agg.py", line 215, in get_text_width_height_descent
    self.mathtext_parser.parse(s, self.dpi, prop)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/mathtext.py", line 86, in parse
    return self._parse_cached(s, dpi, prop, antialiased, load_glyph_flags)
           ~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/mathtext.py", line 100, in _parse_cached
    box = self._parser.parse(s, fontset, fontsize, dpi)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/_mathtext.py", line 2167, in parse
    raise ValueError("\n" + ParseException.explain(err, 0)) from None
ValueError: 
p(x)=\frac{e^{-\frac12(x-\mu)^T\Sigma^{-1}(x-\mu)}}{(2\pi)^{d/2}|\Sigma|^{1/2}}
                    ^
ParseSyntaxException: Expected \frac{num}{den}, found '12'  (at char 20), (line:1, col:21)
ls: cannot access '/mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx': No such file or directory


Command 'bash -lc 'cat > /mnt/data/equation_atlas_1_50/build_book.py <<'"'"'PY'"'"'
from pathlib import Path
import csv, math, textwrap
import numpy as np
import matplotlib.pyplot as plt
from matplotlib.patches import Rectangle
from docx import Document
from docx.shared import Inches, Pt
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.enum.section import WD_SECTION
from docx.enum.table import WD_TABLE_ALIGNMENT, WD_CELL_VERTICAL_ALIGNMENT
from docx.oxml import OxmlElement
from docx.oxml.ns import qn

ROOT=Path(__file__).resolve().parent
ASSETS=ROOT/'"'"'assets'"'"'; ASSETS.mkdir(exist_ok=True)
OUT=ROOT/'"'"'Equation_Atlas_Pages_1_50.docx'"'"'

with (ROOT/'"'"'page_circuit_entropy.csv'"'"').open() as f:
    entrows={int(r['"'"'page'"'"']):r for r in csv.DictReader(f)}

# title, mathtext equation, explanation, AI lens, image prompt
PAGES=[
(1,"Bayes'"'"' Theorem",r"P(A\mid B)=\frac{P(B\mid A)P(A)}{P(B)}",
"Bayes'"'"' theorem is the algebra of belief revision. A prior belief about A is multiplied by how compatible new evidence B is with A, then normalized by the overall probability of observing B. The equation is simple, but its consequence is profound: evidence does not create belief from nothing; it reshapes an existing distribution.",
"Bayesian reasoning appears whenever an AI system must combine uncertain evidence with previous knowledge. Probabilistic classifiers, latent-variable models, Bayesian optimization, filtering, and uncertainty estimation all reuse this pattern. The practical discipline is to separate what the model believed before the observation from what the observation actually supports.",
"A luminous probability landscape folding from prior to posterior, three translucent distributions intersecting around a single observation, scientific infographic, deep space mathematical aesthetic, no readable text."),
(2,"Log-Likelihood",r"\mathcal{L}(\theta)=\sum_i\log p(x_i\mid\theta)",
"The log-likelihood turns a product of many probabilities into a sum. That mathematical conversion is more than convenience: products of tiny probabilities can underflow numerically, while sums of logarithms remain stable. Maximizing log-likelihood is equivalent to maximizing likelihood because the logarithm is monotonic.",
"Most modern learning objectives are log-probability objectives in disguise. Language models minimize negative token log-likelihood; density models maximize log probability of observed data; probabilistic decoders use the same structure. The log scale also makes individual examples additive, so minibatches can estimate the full-data objective efficiently.",
"A field of probability particles collapsing into a smooth logarithmic energy surface, additive evidence streams converging on a parameter peak, elegant scientific visualization, no text."),
(3,"Maximum Likelihood Estimation",r"\hat{\theta}=\arg\max_{\theta}\prod_i p(x_i\mid\theta)",
"Maximum likelihood estimation chooses the parameter value that makes the observed dataset most probable under the model. It is a data-fitting principle: among candidate worlds defined by different parameters, select the one in which the evidence looks least surprising.",
"Training a neural network with cross-entropy is often maximum likelihood performed through gradient descent. The model class determines what distributions are possible; MLE decides which member of that class best explains the training set. Its limitation is equally important: the method optimizes fit to observed data, not automatically robustness, causality, fairness, or calibration.",
"A mountain-like likelihood surface with a bright parameter trajectory reaching the maximum, abstract neural geometry surrounding the peak, cinematic scientific rendering, no text."),
(4,"Entropy",r"H(X)=-\sum_x p(x)\log p(x)",
"Entropy measures uncertainty in a probability distribution. A distribution concentrated on one outcome has low entropy; a distribution spread evenly across many outcomes has high entropy. The logarithm makes independent uncertainties additive and gives entropy its information-theoretic interpretation in bits when base-2 logs are used.",
"In AI, entropy can quantify predictive uncertainty, encourage exploration, regularize policies, measure token diversity, or reveal how concentrated an attention or class distribution has become. High entropy is not inherently good or bad: sometimes it means useful diversity, and sometimes it means the model has no idea what to predict.",
"A probability simplex transforming from a sharp single spike to an evenly distributed constellation, entropy represented as expanding informational volume, minimalist scientific art, no labels."),
(5,"Cross-Entropy",r"H(p,q)=-\sum_x p(x)\log q(x)",
"Cross-entropy measures the coding cost incurred when the true distribution is p but predictions are made using q. It becomes small when q places probability mass where p does, and it grows sharply when the model assigns low probability to events that are actually correct.",
"Classification networks typically minimize cross-entropy between target labels and predicted softmax probabilities. For one-hot targets, the loss reduces to the negative log probability of the correct class. That makes the training signal interpretable: the model is punished most when it is confidently wrong.",
"Two probability landscapes, one ground-truth and one predicted, gradually aligning as an information-cost surface falls between them, polished technical visualization, no text."),
(6,"KL Divergence",r"D_{KL}(P\|Q)=\sum_x P(x)\log\frac{P(x)}{Q(x)}",
"Kullback-Leibler divergence measures how much extra information is required when Q is used to approximate P. It is zero only when the distributions match almost everywhere. Unlike a geometric distance, KL divergence is asymmetric: reversing P and Q changes the question being asked.",
"KL terms appear throughout variational inference, distillation, reinforcement learning, preference optimization, and model regularization. Forward and reverse KL emphasize different failure modes. One often penalizes missing probability mass, while the other can favor concentrating on a dominant mode, so direction matters.",
"Two translucent probability clouds with an asymmetric information flow arrow between them, mismatch rendered as geometric tension, sophisticated mathematical visualization, no text."),
(7,"Mutual Information",r"I(X;Y)=\sum_{x,y}p(x,y)\log\frac{p(x,y)}{p(x)p(y)}",
"Mutual information asks how much knowing one variable reduces uncertainty about another. If X and Y are independent, the joint distribution factorizes and mutual information is zero. Strong dependence raises the value even when the relationship is nonlinear.",
"Representation learning often seeks features that preserve information useful for a target while discarding irrelevant detail. Contrastive objectives, information bottlenecks, feature selection, and multimodal alignment can all be interpreted through mutual information. The difficulty is that exact estimation becomes hard in high dimensions, so practical systems rely on bounds or proxies.",
"Two distant latent manifolds connected by glowing nonlocal information filaments, shared structure emerging despite different coordinates, high-end scientific concept art, no text."),
(8,"Gaussian Distribution",r"p(x)=\frac{1}{\sqrt{2\pi\sigma^2}}e^{-\frac{(x-\mu)^2}{2\sigma^2}}",
"The Gaussian distribution is defined by a mean and variance. The mean locates its center; the variance controls its spread. Its bell shape appears throughout statistics because sums of many weakly dependent effects often approach Gaussian behavior.",
"Gaussian assumptions support noise models, probabilistic embeddings, Kalman-style filtering, weight initialization theory, diffusion processes, and latent-variable models. The distribution is mathematically convenient, but convenience should not be confused with truth: heavy tails, multimodality, and bounded variables can demand different models.",
"A crystalline bell-shaped probability surface floating over a coordinate plane, mean as a central luminous axis and variance as expanding rings, clean scientific render, no text."),
(9,"Multivariate Gaussian",r"p(x)=\frac{e^{-\frac12(x-\mu)^T\Sigma^{-1}(x-\mu)}}{(2\pi)^{d/2}|\Sigma|^{1/2}}",
"The multivariate Gaussian extends the bell curve into many dimensions. Its covariance matrix does two jobs simultaneously: diagonal elements set variance along coordinates, while off-diagonal elements encode linear correlations. Equal-density regions form ellipsoids shaped by the covariance geometry.",
"Multivariate Gaussians are building blocks for Bayesian models, Gaussian processes, latent spaces, uncertainty ellipsoids, and classical state estimators. In advanced AI they also provide a local approximation to complicated distributions, especially when second-order structure is more important than exact global shape.",
"A floating ellipsoidal probability cloud with covariance axes and correlated dimensions bending through latent space, elegant high-dimensional scientific illustration, no text."),
(10,"Jensen-Shannon Divergence",r"JS(P,Q)=\frac12D_{KL}(P\|M)+\frac12D_{KL}(Q\|M),\quad M=\frac{P+Q}{2}",
"Jensen-Shannon divergence symmetrizes and smooths KL divergence by comparing each distribution to their midpoint mixture. It is finite under conditions where KL can explode and treats P versus Q the same as Q versus P.",
"The quantity became especially visible through generative modeling because it describes a stable notion of distributional discrepancy. More broadly, it is useful when model and data distributions need a bounded, symmetric comparison. Its square root is a true metric, which gives the construction stronger geometric behavior than raw KL divergence.",
"Two probability fields flowing into a shared midpoint distribution, then reflecting symmetrically back toward each source, balanced geometric composition, scientific concept art, no text."),
(11,"Affine Transformation",r"z=Wx+b",
"The affine transformation is the linear skeleton of a neural network. The matrix W mixes and rescales input coordinates; the bias b shifts the result. Without a nonlinear activation between affine layers, stacking many such transformations would collapse into a single affine map.",
"Transformers, convolutional networks, multilayer perceptrons, and embedding projections all rely on massive numbers of affine maps. Much of deep learning can be viewed as learning useful coordinate systems through these maps, then introducing nonlinear gates that let the system express curved and compositional decision boundaries.",
"A vector entering a geometric transformation chamber, stretched, rotated, mixed, and shifted into a new coordinate frame, sleek neural-network visual language, no text."),
(12,"ReLU",r"\mathrm{ReLU}(x)=\max(0,x)",
"ReLU keeps positive values and sets negative values to zero. Its piecewise-linear form is computationally cheap and creates networks that are globally nonlinear while remaining locally linear in large regions of input space.",
"ReLU helped make deep networks easier to optimize than saturating activations in many settings. It also creates sparse activations because part of the input range maps exactly to zero. Variants such as GELU, SiLU, and leaky ReLU soften or modify the hard gate, but the underlying idea remains selective nonlinear transmission.",
"A sharp threshold gate in latent space where negative signals vanish and positive signals pass into a luminous linear ramp, architectural technical art, no text."),
(13,"Sigmoid",r"\sigma(x)=\frac{1}{1+e^{-x}}",
"The sigmoid compresses any real number into the interval from zero to one. Near the origin it changes smoothly; at large positive or negative inputs it saturates. This makes it natural for binary probabilities and gates, but saturation can shrink gradients.",
"Sigmoid outputs are common in binary classifiers, independent multilabel heads, recurrent gates, and probabilistic control variables. The function is often best used where a bounded interpretation matters rather than as the universal activation inside every hidden layer.",
"An S-shaped luminous transfer curve passing through a probabilistic gate from zero to one, with saturation zones fading at both extremes, precise scientific graphic, no text."),
(14,"Hyperbolic Tangent",r"\tanh(x)=\frac{e^x-e^{-x}}{e^x+e^{-x}}",
"Tanh maps real values to the interval from minus one to one. Unlike sigmoid, its output is centered around zero, which can make intermediate representations easier to balance. It still saturates for large magnitudes and therefore can suffer vanishing gradients in deep compositions.",
"Tanh remains important in recurrent networks, bounded state updates, classical control systems, and models where signed outputs are useful. Even when newer activations dominate, tanh is a canonical example of how nonlinear squashing changes both representational capacity and gradient flow.",
"A symmetric S-curve spanning negative to positive activation, centered on zero with mirrored saturation wings, elegant mathematical visualization, no text."),
(15,"Softmax",r"\mathrm{softmax}(z_i)=\frac{e^{z_i}}{\sum_j e^{z_j}}",
"Softmax converts arbitrary logits into a normalized categorical distribution. Exponentiation amplifies differences between logits, while division by the sum forces all probabilities to add to one. Adding the same constant to every logit leaves the distribution unchanged.",
"Every autoregressive language model uses a softmax-like normalization to transform vocabulary logits into token probabilities. It also appears in classification and attention. Temperature modifies the sharpness of the same mechanism, making softmax a bridge between raw scores and stochastic decisions.",
"A set of raw vertical energy bars transforming into a normalized probability simplex, one channel rising while all outputs still sum to unity, futuristic scientific art, no text."),
(16,"Multiclass Cross-Entropy Loss",r"\mathcal L=-\sum_i y_i\log\hat y_i",
"Multiclass cross-entropy compares a target class distribution with predicted class probabilities. For one-hot labels, only the correct class contributes directly, so the loss is simply the negative log probability assigned to the target.",
"This objective powers a huge fraction of supervised classification and token prediction. Its logarithmic shape matters: moving a correct prediction from 0.9 to 0.99 helps a little, while assigning 0.001 to the true class is punished severely. That asymmetry drives models away from confident mistakes.",
"A target class beacon and a predicted probability spectrum converging as a logarithmic penalty surface collapses, modern AI training visualization, no text."),
(17,"Mean Squared Error",r"\mathrm{MSE}=\frac1n\sum_i(y_i-\hat y_i)^2",
"Mean squared error averages the squared gap between predictions and targets. Squaring removes sign and makes large errors disproportionately expensive. The loss is smooth and easy to differentiate, which explains its enduring role in regression.",
"MSE appears in regression, reconstruction, distillation, denoising, and diffusion training. It corresponds to maximum likelihood under a Gaussian observation model with fixed variance. Its weakness is sensitivity to outliers: a few large residuals can dominate the objective.",
"Prediction points orbiting a regression curve with squared residual areas glowing more intensely for larger errors, refined technical infographic, no text."),
(18,"Backpropagation",r"\frac{\partial L}{\partial w}=\frac{\partial L}{\partial y}\frac{\partial y}{\partial w}",
"Backpropagation efficiently applies the chain rule through a computational graph. Local derivatives are propagated backward from the loss so that every parameter receives a gradient describing how a small change would affect the final objective.",
"Without backpropagation, training networks with billions of parameters would be computationally impractical. Automatic differentiation systems generalize this idea, storing or recomputing intermediate operations and composing vector-Jacobian products backward through the graph.",
"A deep computational graph illuminated from the loss backward, gradient signals branching through layers toward millions of parameters, cinematic scientific diagram, no text."),
(19,"Gradient Descent",r"\theta_{t+1}=\theta_t-\eta\nabla_\theta L(\theta_t)",
"Gradient descent moves parameters in the direction opposite the local gradient. The learning rate determines step size: too small and progress is slow; too large and the optimizer can oscillate or diverge. The method is local, so the geometry of the loss surface controls the path.",
"Neural training is fundamentally a sequence of such parameter updates, usually modified by minibatching, momentum, adaptive scaling, scheduling, or regularization. Understanding gradient descent means understanding why curvature, noise, normalization, and scale all change learning behavior.",
"A glowing optimization trajectory descending through a folded high-dimensional loss valley, step vectors following local slopes toward a basin, sophisticated mathematical landscape, no text."),
(20,"Chain Rule",r"\frac{\partial f}{\partial x}=\frac{\partial f}{\partial g}\frac{\partial g}{\partial x}",
"The chain rule states how derivatives propagate through compositions. If x influences g and g influences f, then the sensitivity of f to x is the product of the sensitivities along that path. Deep networks are enormous compositions, so this rule is their calculus backbone.",
"Gradient flow, differentiable programming, neural ODEs, meta-learning, and end-to-end optimization all depend on repeated chain-rule composition. Vanishing and exploding gradients emerge because many local derivative factors are multiplied across depth.",
"Nested mathematical transformations connected as a continuous derivative chain, local sensitivities multiplying along a glowing path through deep layers, scientific art, no text."),
(21,"Stochastic Gradient Descent",r"\theta_{t+1}=\theta_t-\eta\nabla_\theta L(\theta_t;x_b)",
"Stochastic gradient descent replaces the exact full-dataset gradient with an estimate from a minibatch. The update is noisy, but drastically cheaper. Repeated noisy steps can still follow the broad direction of the true gradient and sometimes help escape narrow or brittle regions.",
"Nearly all large-scale neural training depends on minibatch gradients. Batch size changes the noise scale, hardware efficiency, and optimization dynamics. SGD is therefore not just an approximation to gradient descent; its stochasticity becomes part of the learning process.",
"A noisy swarm of minibatch gradient arrows collectively drifting down a loss landscape toward a shared basin, energetic but disciplined scientific visualization, no text."),
(22,"Momentum",r"v_t=\beta v_{t-1}+(1-\beta)g_t,\quad \theta_t=\theta_{t-1}-\eta v_t",
"Momentum forms an exponentially smoothed direction from recent gradients. Consistent directions accumulate velocity, while rapidly changing directions tend to cancel. This can speed travel through long valleys and reduce sideways oscillation.",
"Momentum is one of the simplest ways to give optimization memory. Its effect is geometric: the update depends not only on the current slope but also on the recent trajectory. Modern optimizers inherit this idea through moving averages of first moments.",
"A particle carrying velocity through a curved optimization valley, recent gradient arrows blending into a smooth inertial trajectory, elegant dynamical-systems visualization, no text."),
(23,"Adam First Moment",r"m_t=\beta_1m_{t-1}+(1-\beta_1)g_t",
"Adam'"'"'s first moment is an exponential moving average of gradients. It estimates the persistent direction of recent optimization pressure while filtering high-frequency minibatch noise.",
"The first moment behaves like momentum, but Adam combines it with a second moment that rescales updates coordinate by coordinate. In very large models this smoothing helps produce stable progress across parameters whose raw gradients differ substantially in scale.",
"A jagged gradient signal entering an exponential smoothing filter and emerging as a steady directional field, modern optimizer infographic, no text."),
(24,"Adam Second Moment",r"v_t=\beta_2v_{t-1}+(1-\beta_2)g_t^2",
"Adam'"'"'s second moment tracks an exponential average of squared gradients. Because the square removes sign, the quantity estimates recent gradient magnitude rather than direction. Large values indicate coordinates experiencing consistently large updates.",
"Dividing by the square root of this moment normalizes step sizes, allowing parameters with different gradient scales to learn at more comparable effective rates. The stabilizing constant epsilon prevents division by zero and matters in low-precision numerical regimes.",
"A gradient magnitude signal squared and accumulated into an adaptive scale field, high-energy coordinates compressed while quiet coordinates remain visible, scientific graphic, no text."),
(25,"Adam Update",r"\theta_t=\theta_{t-1}-\eta\frac{\hat m_t}{\sqrt{\hat v_t}+\epsilon}",
"The Adam update combines a direction estimate from the first moment with scale normalization from the second. Bias-corrected moments compensate for initialization near zero, especially during early optimization steps.",
"Adam and related optimizers are standard tools for transformer training because they tolerate heterogeneous gradient scales and noisy minibatches. They do not eliminate the need for good learning-rate schedules, clipping, initialization, or regularization; they change the geometry of the step.",
"A multidimensional optimizer vector being directionally smoothed and scale-normalized before entering a parameter landscape, premium scientific visualization, no text."),
(26,"L2 Regularization",r"L_{reg}=L+\lambda\|\theta\|_2^2",
"L2 regularization adds a penalty proportional to squared parameter magnitude. Large weights become more expensive, encouraging solutions with smaller overall norm. The penalty is smooth and spreads pressure across many parameters.",
"Regularization can improve generalization when model capacity exceeds the information available in the data. In neural networks, explicit L2 penalties and optimizer-level weight decay are closely related but not always identical, especially for adaptive optimizers.",
"A parameter vector being pulled inward toward a smooth spherical norm boundary while preserving task fit, clean geometric regularization illustration, no text."),
(27,"L1 Regularization",r"L_{reg}=L+\lambda\|\theta\|_1",
"L1 regularization penalizes the sum of absolute parameter magnitudes. Its sharp geometry at zero encourages some parameters to become exactly or nearly zero, producing sparse solutions.",
"Sparsity can support feature selection, compression, interpretable linear models, or structured pruning. In massive neural networks, practical sparsity often requires specialized methods, but the L1 objective remains the canonical mathematical route from regularization to zeros.",
"A high-dimensional parameter cloud collapsing onto sparse coordinate axes and sharp diamond-shaped norm contours, precise mathematical illustration, no text."),
(28,"Newton'"'"'s Method",r"\theta_{t+1}=\theta_t-H^{-1}\nabla L",
"Newton'"'"'s method uses both the gradient and the Hessian, a matrix of second derivatives. The Hessian estimates local curvature, allowing the optimizer to rescale directions according to how sharply the loss bends.",
"Exact Newton steps are usually too expensive for modern deep networks because the Hessian is enormous. Yet the principle survives in quasi-Newton methods, natural-gradient ideas, curvature approximations, second-order diagnostics, and preconditioners.",
"A curved loss surface with local Hessian geometry reshaping a gradient step into a direct curvature-aware jump toward the optimum, advanced mathematical visualization, no text."),
(29,"Scaled Dot-Product Attention",r"\mathrm{Attention}(Q,K,V)=\mathrm{softmax}\!\left(\frac{QK^T}{\sqrt{d_k}}\right)V",
"Attention compares queries with keys through dot products, scales the scores, normalizes them with softmax, and uses the resulting weights to mix values. The square-root scaling prevents dot products from growing too large as key dimension increases.",
"This equation is the central routing mechanism of the transformer. It lets every token construct a context-dependent weighted view of other tokens. What a model retrieves is therefore not stored in one fixed location; it is dynamically assembled from relationships among query, key, and value representations.",
"A transformer token projecting query beams across a field of keys, softmax weights illuminating selected value streams that recombine into context, cinematic AI visualization, no text."),
(30,"Multi-Head Attention",r"\mathrm{MHA}(Q,K,V)=\mathrm{Concat}(head_1,\ldots,head_h)W^O",
"Multi-head attention runs several attention mechanisms in parallel, concatenates their outputs, and projects the result back into the model dimension. Each head has its own learned projections, so heads can specialize in different relational patterns.",
"Parallel heads increase representational flexibility: one head may track local syntax, another long-distance dependencies, another formatting or positional structure. Head behavior is not guaranteed to be cleanly interpretable, but the architecture creates multiple simultaneous channels for context routing.",
"Several distinct attention beams operating in parallel over the same token field, then merging through a final projection into one coherent representation, polished technical art, no text."),
(31,"Attention Head",r"head_i=\mathrm{Attention}(QW_i^Q,KW_i^K,VW_i^V)",
"An attention head first projects queries, keys, and values into head-specific subspaces. Attention is then computed inside that learned coordinate system. The projections determine which features are visible to that head before any token-to-token comparison occurs.",
"Thinking of a head as only an attention matrix misses half the mechanism. The learned Q, K, and V projections define what similarity means and what information is carried forward. Head specialization therefore emerges from both routing weights and representational subspaces.",
"One attention head shown as three learned projection lenses for query, key, and value, converging into a focused relational map, high-detail scientific diagram, no text."),
(32,"Transformer Residual Connection",r"x'"'"'=x+\mathrm{Attention}(x)",
"A residual connection adds a module'"'"'s transformation back to its input. Rather than forcing each layer to replace the representation, the layer can learn an incremental correction. This creates a persistent information pathway through depth.",
"Residual streams are fundamental to deep transformers because they improve gradient flow and allow many modules to write into a shared evolving representation. Modern block ordering can be pre-normalized or post-normalized, but residual addition remains the backbone connecting layers.",
"A continuous residual information stream flowing through many transformer layers while attention modules inject structured corrections into it, elegant architecture visualization, no text."),
(33,"Layer Normalization",r"\mathrm{LN}(x)=\gamma\frac{x-\mu}{\sqrt{\sigma^2+\epsilon}}+\beta",
"Layer normalization centers and scales the features of an individual example, then restores learnable scale and offset through gamma and beta. Unlike batch normalization, it does not require statistics across different examples in a minibatch.",
"Transformers rely heavily on layer normalization or close variants such as RMSNorm. Normalization controls activation scale, stabilizes deep residual stacks, and changes the effective geometry seen by attention and feed-forward blocks.",
"A chaotic feature vector entering a normalization field and emerging centered and rescaled, followed by learnable stretching and shifting, clean technical illustration, no text."),
(34,"Transformer Feed-Forward Network",r"\mathrm{FFN}(x)=W_2\,\sigma(W_1x+b_1)+b_2",
"The transformer feed-forward network applies an affine expansion, a nonlinearity, and a projection back to the model dimension. It acts independently at each token position, unlike attention, which mixes information across positions.",
"A useful mental model is that attention routes information between tokens while the FFN performs nonlinear feature transformation within each token. In many large language models, these feed-forward blocks hold a substantial share of the parameters and computational cost.",
"A token representation expanding into a wide nonlinear feature chamber and compressing back into the residual stream, sophisticated transformer internals visualization, no text."),
(35,"Autoregressive Factorization",r"P(x_{1:T})=\prod_{t=1}^{T}P(x_t\mid x_{<t})",
"Autoregressive factorization writes the probability of an entire sequence as a product of next-step conditional probabilities. The chain rule of probability guarantees this factorization; modeling chooses how each conditional distribution is represented.",
"Language models train and generate under this decomposition. At each position the model predicts a distribution conditioned on preceding tokens, then generation repeatedly samples or selects one token and feeds it back as context. Sequence intelligence emerges from iterating a local next-token rule.",
"A sequence of tokens unfolding through time, each new symbol branching from a conditional probability field conditioned on the entire prior path, cinematic AI visualization, no text."),
(36,"Language-Model Loss",r"L=-\sum_{t=1}^{T}\log P(x_t\mid x_{<t})",
"The language-model objective sums the negative log probability assigned to the correct next token at every position. Minimizing it is equivalent to maximizing the likelihood of the observed training sequences under the autoregressive model.",
"This deceptively compact loss scales to enormous datasets and model sizes. It does not explicitly instruct the model to reason, summarize, code, or converse; those capabilities can emerge because accurate next-token prediction requires capturing increasingly rich structure in the data distribution.",
"A long token stream passing through a predictive field where each correct next token lowers a cumulative log-loss energy trace, refined AI training artwork, no text."),
(37,"Causal Attention Mask",r"A_{ij}=\begin{cases}0,&j\le i\\-\infty,&j>i\end{cases}",
"The causal mask prevents a position from attending to future positions during autoregressive training. Adding negative infinity before softmax forces disallowed attention weights to zero, preserving the same information constraint used during generation.",
"Without this mask, a language model could cheat by directly reading future tokens while being trained to predict them. The mask therefore turns a parallel training computation into a valid simulation of sequential prediction.",
"A triangular attention matrix with the future region sealed behind an impenetrable boundary while the past remains illuminated and accessible, crisp scientific diagram, no text."),
(38,"Rotary Position Embedding",r"\begin{pmatrix}x'"'"'_{2i}\\x'"'"'_{2i+1}\end{pmatrix}=\begin{pmatrix}\cos\theta_i&-\sin\theta_i\\\sin\theta_i&\cos\theta_i\end{pmatrix}\begin{pmatrix}x_{2i}\\x_{2i+1}\end{pmatrix}",
"Rotary position embeddings encode position by rotating pairs of feature coordinates by position-dependent angles. Relative displacement between positions becomes embedded in the phase difference between their rotated query and key components.",
"RoPE is widely used in modern language models because it integrates positional structure directly into attention geometry. Extensions that rescale or interpolate its frequencies are also used to support contexts longer than those seen during original training.",
"Pairs of latent coordinates rotating around concentric phase circles as token position advances, relative angles forming structured attention geometry, elegant mathematical art, no text."),
(39,"Evidence Lower Bound",r"\log p(x)\ge \mathbb E_{q(z\mid x)}[\log p(x\mid z)]-D_{KL}(q(z\mid x)\|p(z))",
"The evidence lower bound replaces an often-intractable marginal likelihood with a tractable objective. Its first term rewards latent codes that reconstruct or explain the observation; its KL term keeps the approximate posterior close to a chosen prior.",
"ELBO optimization powers variational inference and variational autoencoders. The equation exposes a central tradeoff in representation learning: preserve enough information in z to model the data while maintaining a latent distribution that remains regular and sampleable.",
"A latent-variable model balancing reconstruction fidelity against a smooth prior geometry on opposite sides of a lower-bound scale, sophisticated generative-model visualization, no text."),
(40,"VAE Objective",r"L_{VAE}=-\mathbb E_{q(z\mid x)}[\log p(x\mid z)]+D_{KL}(q(z\mid x)\|p(z))",
"The VAE loss is the negative form of the ELBO: reconstruction error plus a KL regularizer. The encoder maps data to a distribution over latent variables; the decoder reconstructs data from samples drawn from that latent distribution.",
"Unlike a deterministic autoencoder, a VAE explicitly shapes a probabilistic latent space. That enables interpolation and generation, but strong regularization can also cause posterior collapse, where the decoder ignores the latent variable because using it is not worth the KL cost.",
"An encoder transforming data into a smooth probabilistic latent cloud, samples crossing a bottleneck into a decoder, reconstruction and regularity in visual balance, no text."),
(41,"GAN Discriminator Objective",r"\max_D\;\mathbb E_{x\sim p_{data}}\log D(x)+\mathbb E_{z\sim p(z)}\log(1-D(G(z)))",
"The discriminator is trained to assign high scores to real data and low scores to generated samples. Its objective turns generative learning into a competitive game: distinguish reality from synthesis as accurately as possible.",
"A strong discriminator provides the generator with a learned training signal that does not require an explicit likelihood. The adversarial game can produce sharp samples, but it is also vulnerable to instability, vanishing gradients, and mode collapse when the two players become unbalanced.",
"A discriminator boundary separating real and generated sample clouds while both distributions evolve in response, adversarial game rendered as dynamic geometry, no text."),
(42,"GAN Generator Objective",r"\min_G\;\mathbb E_{z\sim p(z)}[\log(1-D(G(z)))]",
"The generator transforms noise into synthetic samples and adjusts itself according to the discriminator'"'"'s judgment. In the original minimax formulation it tries to minimize the probability that generated samples are detected as fake.",
"Practical GAN training often uses a non-saturating generator loss for stronger gradients, but the core idea is unchanged: a generator learns indirectly through an adversary. This creates an adaptive objective whose shape changes as the discriminator improves.",
"A generator morphing latent noise into structured samples while crossing an adversarial decision boundary that shifts in response, high-end AI concept art, no text."),
(43,"Diffusion Forward Process",r"q(x_t\mid x_{t-1})=\mathcal N(\sqrt{1-\beta_t}\,x_{t-1},\beta_t I)",
"The forward diffusion process gradually corrupts data with Gaussian noise. At each step, part of the previous signal is retained and fresh noise is added according to a schedule beta_t. After enough steps, structured data becomes close to simple noise.",
"The forward process is deliberately easy; the intelligence is learned in reversing it. By creating a known corruption path, diffusion models turn generation into a sequence of denoising problems rather than a single jump from noise to data.",
"A detailed image dissolving through successive layers of Gaussian noise until only an isotropic cloud remains, smooth time progression, cinematic generative-model visualization, no text."),
(44,"Closed-Form Diffusion Noising",r"x_t=\sqrt{\bar\alpha_t}x_0+\sqrt{1-\bar\alpha_t}\,\epsilon",
"The closed-form noising equation allows a model to sample any diffusion timestep directly from clean data. The coefficient on x_0 controls retained signal, while the coefficient on epsilon controls injected noise.",
"This shortcut is crucial for efficient training: there is no need to simulate every previous diffusion step before producing x_t. A random timestep can be selected, noised in one operation, and used to train the denoiser.",
"A clean signal and pure noise mixed by two complementary square-root coefficients into a family of intermediate states across time, elegant scientific visualization, no text."),
(45,"Diffusion Denoising Objective",r"L=\mathbb E_{t,x_0,\epsilon}\left[\|\epsilon-\epsilon_\theta(x_t,t)\|^2\right]",
"A common diffusion objective trains the network to predict the exact noise added to a corrupted sample. The error is measured with a squared norm across randomly selected examples, timesteps, and noise draws.",
"Noise prediction is attractive because the target is known exactly during training. Once the network can estimate the noise component at many corruption levels, a sampler can repeatedly remove predicted noise and reconstruct structured data from an initially random state.",
"A neural denoiser extracting a precise noise vector from a corrupted state, repeated stages revealing structured data from randomness, cinematic generative AI art, no text."),
(46,"Expected Discounted Return",r"G_t=\sum_{k=0}^{\infty}\gamma^kR_{t+k+1}",
"The return adds future rewards while discounting distant outcomes by powers of gamma. A gamma near zero emphasizes immediate rewards; a gamma near one gives long-horizon consequences more influence.",
"Reinforcement-learning agents optimize behavior through estimates of return. Discounting controls effective planning horizon and keeps infinite sums mathematically manageable. The choice of reward function and gamma together defines what the agent is actually incentivized to value over time.",
"A branching decision timeline where future rewards glow with exponentially fading intensity as distance from the present increases, elegant reinforcement-learning visualization, no text."),
(47,"Bellman Equation",r"V^\pi(s)=\mathbb E_\pi[R_{t+1}+\gamma V^\pi(S_{t+1})\mid S_t=s]",
"The Bellman equation expresses a value recursively: the worth of a state equals expected immediate reward plus the discounted value of the next state. This turns a long-horizon problem into a local consistency condition.",
"Dynamic programming, temporal-difference learning, actor-critic methods, and many planning algorithms depend on Bellman structure. A value function is correct when its predictions agree with the one-step reward-plus-next-value targets generated by the environment and policy.",
"A state-value landscape recursively reflecting immediate reward and the value of future states, nested decision geometry converging to a fixed point, scientific art, no text."),
(48,"Q-Learning Update",r"Q(s,a)\leftarrow Q(s,a)+\alpha[r+\gamma\max_{a'"'"'}Q(s'"'"',a'"'"')-Q(s,a)]",
"Q-learning updates an action value toward a target built from observed reward plus the best estimated next-state action value. The bracketed difference is the temporal-difference error: a measure of surprise relative to the current estimate.",
"Because the target uses a max over next actions, Q-learning is off-policy: it can learn about a greedy policy while data comes from a more exploratory behavior policy. Deep Q-networks replace the table of Q-values with a neural approximator and add stabilization machinery.",
"A state-action value grid receiving temporal-difference correction pulses, values propagating backward from rewarding future states, advanced reinforcement-learning visualization, no text."),
(49,"Policy Gradient",r"\nabla_\theta J(\theta)=\mathbb E_{\pi_\theta}[\nabla_\theta\log\pi_\theta(a\mid s)G_t]",
"The policy-gradient theorem adjusts policy parameters directly. Actions that produced high returns become more likely because their log-probability gradients are reinforced; low-return actions are pushed in the opposite direction when advantages or centered returns are used.",
"Policy gradients support continuous actions and complex stochastic policies without requiring explicit maximization over every possible action. Variance reduction is essential in practice, which is why baselines, value critics, generalized advantage estimation, and clipping are common companions.",
"A stochastic policy distribution deforming toward high-return actions under gradient pressure, probability mass flowing across an action landscape, cinematic RL visualization, no text."),
(50,"PPO Clipped Objective",r"L^{CLIP}(\theta)=\mathbb E_t\left[\min\!\left(r_tA_t,\mathrm{clip}(r_t,1-\epsilon,1+\epsilon)A_t\right)\right]",
"Proximal Policy Optimization limits how much the new policy can benefit from moving too far from the behavior policy in one update. The probability ratio r_t measures policy change; clipping creates a plateau once the change exceeds a trusted interval.",
"PPO became popular because it approximates trust-region behavior with a relatively simple first-order objective. It is used in simulated control and has also played a major role in reinforcement learning from human feedback, where stable policy updates are especially important.",
"A policy-update curve entering a protected clipping corridor, aggressive probability-ratio movement flattened beyond trusted boundaries while advantage guides direction, polished scientific art, no text."),
]

# category labels
cats={range(1,11):'"'"'Probability & Information'"'"',range(11,21):'"'"'Neural Foundations'"'"',range(21,29):'"'"'Optimization'"'"',range(29,39):'"'"'Transformers & Sequence Models'"'"',range(39,46):'"'"'Generative Models'"'"',range(46,51):'"'"'Reinforcement Learning'"'"'}
def category(i):
    for r,n in cats.items():
        if i in r:return n

# Writing modulation based on entropy; visible text never names the mechanism.
openers_low=["The useful intuition is concrete:","Read this equation operationally:","At its core:"]
openers_mid=["A useful way to read it is this:","The deeper pattern is compact:","One practical interpretation is:"]
openers_high=["Seen geometrically, the equation says:","Viewed as an information flow, it says:","At a systems level, the relation says:"]

def opener(i):
    e=float(entrows[i]['"'"'mean_entanglement_entropy'"'"'])
    choices=openers_low if e<0.4 else openers_mid if e<0.75 else openers_high
    return choices[(i*7)%len(choices)]

# --- figures ---
def save_formula(i, eq):
    fig=plt.figure(figsize=(7,1.05),dpi=180)
    fig.patch.set_alpha(0)
    ax=fig.add_axes([0,0,1,1]); ax.axis('"'"'off'"'"')
    ax.text(0.5,0.5,'"'"'$'"'"'+eq+'"'"'$'"'"',ha='"'"'center'"'"',va='"'"'center'"'"',fontsize=20)
    p=ASSETS/f'"'"'formula_{i:03d}.png'"'"'; fig.savefig(p,transparent=True,bbox_inches='"'"'tight'"'"',pad_inches=0.12); plt.close(fig); return p

def clean(ax,xlab=None,ylab=None):
    ax.spines['"'"'top'"'"'].set_visible(False); ax.spines['"'"'right'"'"'].set_visible(False)
    ax.grid(True,alpha=.18,linewidth=.6)
    ax.tick_params(labelsize=7)
    if xlab: ax.set_xlabel(xlab,fontsize=7)
    if ylab: ax.set_ylabel(ylab,fontsize=7)

def save_chart(i):
    fig,ax=plt.subplots(figsize=(6.3,2.05),dpi=180)
    x=np.linspace(-4,4,240)
    if i==1:
        lr=np.logspace(-2,2,240); prior=.2; post=(lr*prior)/(lr*prior+1-prior); ax.semilogx(lr,post); clean(ax,'"'"'likelihood ratio'"'"','"'"'posterior'"'"')
    elif i==2:
        data=np.array([-1.1,-.6,-.1,.2,.8,1.0]); mu=np.linspace(-2,2,240); ll=np.array([-0.5*np.sum((data-m)**2) for m in mu]); ax.plot(mu,ll); clean(ax,'"'"'parameter μ'"'"','"'"'log-likelihood'"'"')
    elif i==3:
        th=np.linspace(-2,2,240); lik=np.exp(-2*(th-.45)**2); ax.plot(th,lik); ax.axvline(.45,ls='"'"'--'"'"',lw=1); clean(ax,'"'"'θ'"'"','"'"'likelihood'"'"')
    elif i==4:
        p=np.linspace(.001,.999,240); h=-(p*np.log2(p)+(1-p)*np.log2(1-p)); ax.plot(p,h); clean(ax,'"'"'P(X=1)'"'"','"'"'entropy (bits)'"'"')
    elif i==5:
        q=np.linspace(.01,.99,240); ax.plot(q,-np.log(q)); clean(ax,'"'"'predicted probability of truth'"'"','"'"'cross-entropy'"'"')
    elif i==6:
        q=np.linspace(.02,.98,240); p=.72; d=p*np.log(p/q)+(1-p)*np.log((1-p)/(1-q)); ax.plot(q,d); clean(ax,'"'"'Q probability'"'"','"'"'KL(P||Q)'"'"')
    elif i==7:
        rho=np.linspace(-.98,.98,240); mi=-.5*np.log(1-rho**2); ax.plot(rho,mi); clean(ax,'"'"'correlation proxy'"'"','"'"'mutual information'"'"')
    elif i==8:
        for s in [.6,1.0,1.5]: ax.plot(x,np.exp(-x*x/(2*s*s))/(np.sqrt(2*np.pi)*s))
        clean(ax,'"'"'x'"'"','"'"'density'"'"')
    elif i==9:
        xx=np.linspace(-3,3,220); ax.plot(xx,np.exp(-.5*xx**2)); ax.plot(xx,np.exp(-.5*(xx/1.7)**2)/1.7); clean(ax,'"'"'principal axis'"'"','"'"'density slice'"'"')
    elif i==10:
        q=np.linspace(.01,.99,240); p=.75; m=(p+q)/2; js=.5*(p*np.log(p/m)+(1-p)*np.log((1-p)/(1-m)))+.5*(q*np.log(q/m)+(1-q)*np.log((1-q)/(1-m))); ax.plot(q,js); clean(ax,'"'"'Q probability'"'"','"'"'JS divergence'"'"')
    elif i==11:
        ax.plot(x,1.4*x+.6); clean(ax,'"'"'x'"'"','"'"'Wx+b'"'"')
    elif i==12:
        ax.plot(x,np.maximum(0,x)); clean(ax,'"'"'x'"'"','"'"'ReLU(x)'"'"')
    elif i==13:
        ax.plot(x,1/(1+np.exp(-x))); clean(ax,'"'"'x'"'"','"'"'σ(x)'"'"')
    elif i==14:
        ax.plot(x,np.tanh(x)); clean(ax,'"'"'x'"'"','"'"'tanh(x)'"'"')
    elif i==15:
        d=np.linspace(-5,5,240); p=1/(1+np.exp(-d)); ax.plot(d,p); clean(ax,'"'"'logit advantage'"'"','"'"'softmax probability'"'"')
    elif i==16:
        p=np.linspace(.01,.999,240); ax.plot(p,-np.log(p)); clean(ax,'"'"'correct-class probability'"'"','"'"'loss'"'"')
    elif i==17:
        e=np.linspace(-3,3,240); ax.plot(e,e**2); clean(ax,'"'"'prediction error'"'"','"'"'squared error'"'"')
    elif i==18:
        depth=np.arange(1,13); a=.82; ax.plot(depth,a**depth,marker='"'"'o'"'"'); clean(ax,'"'"'chain depth'"'"','"'"'gradient product'"'"')
    elif i==19:
        th=np.linspace(-3,3,240); ax.plot(th,th**2); pts=[2.7];
        for _ in range(8): pts.append(pts[-1]-.18*(2*pts[-1]))
        ax.plot(pts,np.array(pts)**2,marker='"'"'o'"'"'); clean(ax,'"'"'θ'"'"','"'"'loss'"'"')
    elif i==20:
        xx=np.linspace(-2,2,240); ax.plot(xx,np.cos(xx)*2*xx); clean(ax,'"'"'x'"'"','"'"'composed derivative'"'"')
    elif i==21:
        rng=np.random.default_rng(21); steps=70; y=[3.0]
        for t in range(steps-1): y.append(y[-1]-.08*(2*y[-1]+rng.normal(0,.8)))
        ax.plot(y); clean(ax,'"'"'minibatch step'"'"','"'"'parameter'"'"')
    elif i==22:
        t=np.arange(60); raw=np.sin(t/5)*np.exp(-t/35); mom=np.convolve(raw,np.ones(8)/8,mode='"'"'same'"'"'); ax.plot(t,raw,alpha=.6); ax.plot(t,mom,lw=2); clean(ax,'"'"'step'"'"','"'"'gradient / momentum'"'"')
    elif i==23:
        t=np.arange(60); g=np.where(t<15,0,1.0); m=np.zeros_like(g,float)
        for k in range(1,len(t)):m[k]=.9*m[k-1]+.1*g[k]
        ax.plot(t,g,alpha=.5); ax.plot(t,m,lw=2); clean(ax,'"'"'step'"'"','"'"'first moment'"'"')
    elif i==24:
        t=np.arange(60); g=np.where(t<18,.2,1.2); v=np.zeros_like(g,float)
        for k in range(1,len(t)):v[k]=.95*v[k-1]+.05*g[k]**2
        ax.plot(t,g**2,alpha=.5); ax.plot(t,v,lw=2); clean(ax,'"'"'step'"'"','"'"'second moment'"'"')
    elif i==25:
        g=np.linspace(.01,3,240); update=g/(np.sqrt(g*g)+.1); ax.plot(g,update); clean(ax,'"'"'gradient scale'"'"','"'"'normalized update'"'"')
    elif i==26:
        w=np.linspace(-3,3,240); ax.plot(w,w*w); clean(ax,'"'"'weight'"'"','"'"'L2 penalty'"'"')
    elif i==27:
        w=np.linspace(-3,3,240); ax.plot(w,np.abs(w)); clean(ax,'"'"'weight'"'"','"'"'L1 penalty'"'"')
    elif i==28:
        th=np.linspace(-3,3,240); ax.plot(th,(th-.8)**2+.15*(th-.8)**4); pts=[2.8,1.55,1.02,.84,.801]; ax.plot(pts,[(p-.8)**2+.15*(p-.8)**4 for p in pts],marker='"'"'o'"'"'); clean(ax,'"'"'θ'"'"','"'"'loss'"'"')
    elif i==29:
        s=np.linspace(-4,4,240); ax.plot(s,1/(1+np.exp(-s))); clean(ax,'"'"'scaled dot-product score'"'"','"'"'attention weight'"'"')
    elif i==30:
        pos=np.arange(20)
        for h in range(4): ax.plot(pos,np.exp(-((pos-(4+4*h))**2)/(2*(1.5+h*.3)**2)))
        clean(ax,'"'"'token position'"'"','"'"'head response'"'"')
    elif i==31:
        pos=np.arange(24); ax.plot(pos,np.exp(-((pos-15)**2)/8)); clean(ax,'"'"'projected key position'"'"','"'"'head attention'"'"')
    elif i==32:
        xx=np.linspace(-3,3,240); ax.plot(xx,xx,ls='"'"'--'"'"',alpha=.7); ax.plot(xx,xx+.35*np.sin(2*xx)); clean(ax,'"'"'input residual'"'"','"'"'updated residual'"'"')
    elif i==33:
        vals=np.array([-3,-1.2,-.7,.1,.5,2.7,5.1]); norm=(vals-vals.mean())/vals.std(); ax.plot(vals,marker='"'"'o'"'"'); ax.plot(norm,marker='"'"'o'"'"'); clean(ax,'"'"'feature index'"'"','"'"'value'"'"')
    elif i==34:
        xx=np.linspace(-3,3,240); ax.plot(xx,.6*np.tanh(1.5*xx+0.5)-.35*np.tanh(.7*xx-1)); clean(ax,'"'"'token feature'"'"','"'"'FFN output'"'"')
    elif i==35:
        t=np.arange(1,30); p=.92**t; ax.plot(t,p); clean(ax,'"'"'sequence length'"'"','"'"'joint probability proxy'"'"')
    elif i==36:
        p=np.linspace(.01,.999,240); ax.plot(p,-np.log(p)); clean(ax,'"'"'next-token probability'"'"','"'"'token loss'"'"')
    elif i==37:
        n=14; mask=np.tril(np.ones((n,n))); ax.imshow(mask,aspect='"'"'auto'"'"',origin='"'"'upper'"'"'); ax.set_xlabel('"'"'key position'"'"',fontsize=7); ax.set_ylabel('"'"'query position'"'"',fontsize=7); ax.tick_params(labelsize=6)
    elif i==38:
        a=np.linspace(0,2*np.pi,80); ax.plot(np.cos(a),np.sin(a),alpha=.35); pts=np.linspace(0,1.8,10); ax.scatter(np.cos(pts),np.sin(pts),s=14); ax.set_aspect('"'"'equal'"'"'); clean(ax,'"'"'rotated dim 1'"'"','"'"'rotated dim 2'"'"')
    elif i==39:
        z=np.linspace(0,1,240); recon=(1-z)**2; kl=z**2*.6; ax.plot(z,recon); ax.plot(z,kl); ax.plot(z,recon+kl,lw=2); clean(ax,'"'"'latent regularization'"'"','"'"'objective terms'"'"')
    elif i==40:
        z=np.linspace(0,1,240); ax.plot(z,(1-z)**2+.6*z*z); clean(ax,'"'"'regularization strength'"'"','"'"'VAE loss'"'"')
    elif i==41:
        D=np.linspace(.01,.99,240); obj=np.log(D)+np.log(1-D); ax.plot(D,obj); clean(ax,'"'"'discriminator confidence'"'"','"'"'balanced objective'"'"')
    elif i==42:
        D=np.linspace(.01,.99,240); ax.plot(D,np.log(1-D)); clean(ax,'"'"'D(G(z))'"'"','"'"'generator minimax term'"'"')
    elif i==43:
        t=np.linspace(0,1,240); signal=np.sqrt(1-.92*t); noise=np.sqrt(.92*t); ax.plot(t,signal); ax.plot(t,noise); clean(ax,'"'"'diffusion time'"'"','"'"'coefficient'"'"')
    elif i==44:
        t=np.linspace(0,1,240); ax.plot(t,np.sqrt(1-t)); ax.plot(t,np.sqrt(t)); clean(ax,'"'"'normalized t'"'"','"'"'signal / noise mixing'"'"')
    elif i==45:
        t=np.arange(1,101); ax.plot(t,1/(1+.05*t)+.03); clean(ax,'"'"'training progress'"'"','"'"'noise-prediction loss'"'"')
    elif i==46:
        k=np.arange(0,40); ax.plot(k,.95**k); ax.plot(k,.8**k); clean(ax,'"'"'future step'"'"','"'"'discount weight'"'"')
    elif i==47:
        it=np.arange(25); ax.plot(it,1-np.exp(-it/5)); clean(ax,'"'"'Bellman iteration'"'"','"'"'value estimate'"'"')
    elif i==48:
        it=np.arange(45); q=1-np.exp(-it/8)+.08*np.sin(it/2)*np.exp(-it/18); ax.plot(it,q); clean(ax,'"'"'update'"'"','"'"'Q estimate'"'"')
    elif i==49:
        th=np.linspace(-4,4,240); reward=np.exp(-.5*(th-1.2)**2); ax.plot(th,reward); ax.annotate('"'"''"'"',xy=(.7,np.exp(-.5*(.7-1.2)**2)),xytext=(-.2,np.exp(-.5*(-.2-1.2)**2)),arrowprops={'"'"'arrowstyle'"'"':'"'"'->'"'"'}); clean(ax,'"'"'policy parameter'"'"','"'"'expected return'"'"')
    elif i==50:
        r=np.linspace(.5,1.5,240); A=1.; eps=.2; unclipped=r*A; clipped=np.clip(r,1-eps,1+eps)*A; ax.plot(r,np.minimum(unclipped,clipped)); ax.axvline(1-eps,ls='"'"'--'"'"',lw=1); ax.axvline(1+eps,ls='"'"'--'"'"',lw=1); clean(ax,'"'"'probability ratio r'"'"','"'"'clipped surrogate'"'"')
    fig.tight_layout(pad=.55)
    p=ASSETS/f'"'"'chart_{i:03d}.png'"'"'; fig.savefig(p,bbox_inches='"'"'tight'"'"'); plt.close(fig); return p

for i,title,eq,*_ in PAGES:
    save_formula(i,eq); save_chart(i)

# --- docx helpers ---
def set_cell_shading(cell, fill='"'"'F3F4F6'"'"'):
    tcPr=cell._tc.get_or_add_tcPr(); shd=OxmlElement('"'"'w:shd'"'"'); shd.set(qn('"'"'w:fill'"'"'),fill); tcPr.append(shd)

def set_repeat_table_borders_none(table):
    tblPr=table._tbl.tblPr
    borders=OxmlElement('"'"'w:tblBorders'"'"')
    for edge in ('"'"'top'"'"','"'"'left'"'"','"'"'bottom'"'"','"'"'right'"'"','"'"'insideH'"'"','"'"'insideV'"'"'):
        el=OxmlElement(f'"'"'w:{edge}'"'"'); el.set(qn('"'"'w:val'"'"'),'"'"'nil'"'"'); borders.append(el)
    tblPr.append(borders)

def add_text(doc,text,size=9.1,bold=False,italic=False,space_after=3,align=None):
    p=doc.add_paragraph(); p.paragraph_format.space_after=Pt(space_after); p.paragraph_format.line_spacing=1.04
    if align is not None:p.alignment=align
    r=p.add_run(text); r.bold=bold; r.italic=italic; r.font.size=Pt(size); r.font.name='"'"'Aptos'"'"'
    return p

D=Document()
sec=D.sections[0]
sec.page_width=Inches(6); sec.page_height=Inches(9)
sec.top_margin=Inches(.42); sec.bottom_margin=Inches(.42); sec.left_margin=Inches(.52); sec.right_margin=Inches(.52)
sec.header_distance=Inches(.18); sec.footer_distance=Inches(.2)

styles=D.styles
styles['"'"'Normal'"'"'].font.name='"'"'Aptos'"'"'; styles['"'"'Normal'"'"'].font.size=Pt(9.1)

# header/footer
hp=sec.header.paragraphs[0]; hp.alignment=WD_ALIGN_PARAGRAPH.CENTER
hr=hp.add_run('"'"'THE EQUATION ATLAS OF ADVANCED AI  •  PAGES 1–50'"'"'); hr.font.name='"'"'Aptos'"'"'; hr.font.size=Pt(6.8); hr.font.bold=True
fp=sec.footer.paragraphs[0]; fp.alignment=WD_ALIGN_PARAGRAPH.CENTER
# PAGE field
run=fp.add_run(); fld=OxmlElement('"'"'w:fldSimple'"'"'); fld.set(qn('"'"'w:instr'"'"'),'"'"'PAGE'"'"'); run._r.addnext(fld)

for idx,(i,title,eq,meaning,ai,prompt) in enumerate(PAGES):
    # small category line
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(0); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run(category(i).upper()); r.font.size=Pt(6.7); r.font.bold=True; r.font.name='"'"'Aptos'"'"';
    p2=D.add_paragraph(); p2.paragraph_format.space_after=Pt(1); p2.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p2.add_run(f'"'"'{i:02d}  ·  {title}'"'"'); r.font.size=Pt(14.2); r.font.bold=True; r.font.name='"'"'Aptos Display'"'"'
    # formula
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(2); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(ASSETS/f'"'"'formula_{i:03d}.png'"'"'),width=Inches(4.55))

    # prose
    e=float(entrows[i]['"'"'mean_entanglement_entropy'"'"'])
    size=8.85 if e>0.78 else 9.0 if e>0.45 else 9.15
    add_text(D,opener(i)+'"'"' '"'"'+meaning,size=size,space_after=3)
    add_text(D,ai,size=size,space_after=3)

    # chart
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(1); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    p.add_run().add_picture(str(ASSETS/f'"'"'chart_{i:03d}.png'"'"'),width=Inches(4.72))
    p=D.add_paragraph(); p.paragraph_format.space_after=Pt(2); p.alignment=WD_ALIGN_PARAGRAPH.CENTER
    r=p.add_run('"'"'Concept graph — a compact visual intuition, not a benchmark result.'"'"'); r.font.size=Pt(6.5); r.font.italic=True; r.font.name='"'"'Aptos'"'"'

    # image prompt box
    tbl=D.add_table(rows=1,cols=1); tbl.alignment=WD_TABLE_ALIGNMENT.CENTER; tbl.autofit=False; tbl.columns[0].width=Inches(4.75)
    set_repeat_table_borders_none(tbl); cell=tbl.cell(0,0); cell.vertical_alignment=WD_CELL_VERTICAL_ALIGNMENT.CENTER; set_cell_shading(cell)
    cell.margin_top=Inches(.05); cell.margin_bottom=Inches(.05)
    pp=cell.paragraphs[0]; pp.paragraph_format.space_after=Pt(0); pp.paragraph_format.line_spacing=1.0
    rr=pp.add_run('"'"'IMAGE PROMPT  '"'"'); rr.bold=True; rr.font.size=Pt(6.5); rr.font.name='"'"'Aptos'"'"'
    rr=pp.add_run(prompt); rr.font.size=Pt(6.45); rr.font.name='"'"'Aptos'"'"'; rr.italic=True

    if i==1:
        p=D.add_paragraph(); p.paragraph_format.space_before=Pt(2); p.paragraph_format.space_after=Pt(0)
        r=p.add_run('"'"'Series note: equations 1–100 summarize established or widely used mathematical ideas; later volumes clearly distinguish speculative constructions.'"'"'); r.font.size=Pt(6.1); r.font.italic=True; r.font.name='"'"'Aptos'"'"'
    if idx < len(PAGES)-1:
        D.add_page_break()

# core props
D.core_properties.title='"'"'The Equation Atlas of Advanced AI — Pages 1–50'"'"'
D.core_properties.subject='"'"'A 500-equation advanced AI fieldbook, first fifty pages'"'"'
D.core_properties.comments='"'"'Prepared as a Kindle/KDP-oriented manuscript segment.'"'"'
D.save(OUT)
print(OUT)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
ls -lh /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx'' failed with status 2.
Analyzed
bash -lc python - <<'PY'
p='/mnt/data/equation_atlas_1_50/build_book.py'
s=open(p).read()
s=s.replace(r"e^{-\frac12(x-\mu)^T", r"e^{-\frac{1}{2}(x-\mu)^T")
open(p,'w').write(s)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
Traceback (most recent call last):
  File "/mnt/data/equation_atlas_1_50/build_book.py", line 374, in <module>
    save_formula(i,eq); save_chart(i)
    ~~~~~~~~~~~~^^^^^^
  File "/mnt/data/equation_atlas_1_50/build_book.py", line 247, in save_formula
    p=ASSETS/f'formula_{i:03d}.png'; fig.savefig(p,transparent=True,bbox_inches='tight',pad_inches=0.12); plt.close(fig); return p
                                     ~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/figure.py", line 3490, in savefig
    self.canvas.print_figure(fname, **kwargs)
    ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/backend_bases.py", line 2157, in print_figure
    self.figure.draw(renderer)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 94, in draw_wrapper
    result = draw(artist, renderer, *args, **kwargs)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/figure.py", line 3257, in draw
    mimage._draw_list_compositing_images(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, self, artists, self.suppressComposite)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/image.py", line 134, in _draw_list_compositing_images
    a.draw(renderer)
    ~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/axes/_base.py", line 3226, in draw
    mimage._draw_list_compositing_images(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, self, artists, self.get_figure(root=True).suppressComposite)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/image.py", line 134, in _draw_list_compositing_images
    a.draw(renderer)
    ~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 752, in draw
    bbox, info, descent = self._get_layout(renderer)
                          ~~~~~~~~~~~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 382, in _get_layout
    w, h, d = _get_text_metrics_with_cache(
              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, clean_line, self._fontproperties,
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        ismath=ismath, dpi=self.get_figure(root=True).dpi)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 69, in _get_text_metrics_with_cache
    return _get_text_metrics_with_cache_impl(
        weakref.ref(renderer), text, fontprop.copy(), ismath, dpi)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 77, in _get_text_metrics_with_cache_impl
    return renderer_ref().get_text_width_height_descent(text, fontprop, ismath)
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/backends/backend_agg.py", line 215, in get_text_width_height_descent
    self.mathtext_parser.parse(s, self.dpi, prop)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/mathtext.py", line 86, in parse
    return self._parse_cached(s, dpi, prop, antialiased, load_glyph_flags)
           ~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/mathtext.py", line 100, in _parse_cached
    box = self._parser.parse(s, fontset, fontsize, dpi)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/_mathtext.py", line 2167, in parse
    raise ValueError("\n" + ParseException.explain(err, 0)) from None
ValueError: 
JS(P,Q)=\frac12D_{KL}(P\|M)+\frac12D_{KL}(Q\|M),\quad M=\frac{P+Q}{2}
             ^
ParseSyntaxException: Expected \frac{num}{den}, found '12D'  (at char 13), (line:1, col:14)


Command 'bash -lc 'python - <<'"'"'PY'"'"'
p='"'"'/mnt/data/equation_atlas_1_50/build_book.py'"'"'
s=open(p).read()
s=s.replace(r"e^{-\frac12(x-\mu)^T", r"e^{-\frac{1}{2}(x-\mu)^T")
open(p,'"'"'w'"'"').write(s)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py'' failed with status 1.
Analyzed
bash -lc python - <<'PY'
p='/mnt/data/equation_atlas_1_50/build_book.py'
s=open(p).read().replace(r'\frac12',r'\frac{1}{2}')
open(p,'w').write(s)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
Traceback (most recent call last):
  File "/mnt/data/equation_atlas_1_50/build_book.py", line 374, in <module>
    save_formula(i,eq); save_chart(i)
    ~~~~~~~~~~~~^^^^^^
  File "/mnt/data/equation_atlas_1_50/build_book.py", line 247, in save_formula
    p=ASSETS/f'formula_{i:03d}.png'; fig.savefig(p,transparent=True,bbox_inches='tight',pad_inches=0.12); plt.close(fig); return p
                                     ~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/figure.py", line 3490, in savefig
    self.canvas.print_figure(fname, **kwargs)
    ~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/backend_bases.py", line 2157, in print_figure
    self.figure.draw(renderer)
    ~~~~~~~~~~~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 94, in draw_wrapper
    result = draw(artist, renderer, *args, **kwargs)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/figure.py", line 3257, in draw
    mimage._draw_list_compositing_images(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, self, artists, self.suppressComposite)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/image.py", line 134, in _draw_list_compositing_images
    a.draw(renderer)
    ~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/axes/_base.py", line 3226, in draw
    mimage._draw_list_compositing_images(
    ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, self, artists, self.get_figure(root=True).suppressComposite)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/image.py", line 134, in _draw_list_compositing_images
    a.draw(renderer)
    ~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/artist.py", line 71, in draw_wrapper
    return draw(artist, renderer)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 752, in draw
    bbox, info, descent = self._get_layout(renderer)
                          ~~~~~~~~~~~~~~~~^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 382, in _get_layout
    w, h, d = _get_text_metrics_with_cache(
              ~~~~~~~~~~~~~~~~~~~~~~~~~~~~^
        renderer, clean_line, self._fontproperties,
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
        ismath=ismath, dpi=self.get_figure(root=True).dpi)
        ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 69, in _get_text_metrics_with_cache
    return _get_text_metrics_with_cache_impl(
        weakref.ref(renderer), text, fontprop.copy(), ismath, dpi)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/text.py", line 77, in _get_text_metrics_with_cache_impl
    return renderer_ref().get_text_width_height_descent(text, fontprop, ismath)
           ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/backends/backend_agg.py", line 215, in get_text_width_height_descent
    self.mathtext_parser.parse(s, self.dpi, prop)
    ~~~~~~~~~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/mathtext.py", line 86, in parse
    return self._parse_cached(s, dpi, prop, antialiased, load_glyph_flags)
           ~~~~~~~~~~~~~~~~~~^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/mathtext.py", line 100, in _parse_cached
    box = self._parser.parse(s, fontset, fontsize, dpi)
  File "/opt/pyvenv/lib/python3.13/site-packages/matplotlib/_mathtext.py", line 2167, in parse
    raise ValueError("\n" + ParseException.explain(err, 0)) from None
ValueError: 
\mathcal L=-\sum_i y_i\log\hat y_i
^
ParseFatalException: Unknown symbol: \mathcal, found '\'  (at char 0), (line:1, col:1)


Command 'bash -lc 'python - <<'"'"'PY'"'"'
p='"'"'/mnt/data/equation_atlas_1_50/build_book.py'"'"'
s=open(p).read().replace(r'"'"'\frac12'"'"',r'"'"'\frac{1}{2}'"'"')
open(p,'"'"'w'"'"').write(s)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py'' failed with status 1.
Analyzed
bash -lc which latex || true; which pdflatex || true
/usr/bin/latex
/usr/bin/pdflatex
Analyzed
bash -lc python - <<'PY'
p='/mnt/data/equation_atlas_1_50/build_book.py'
s=open(p).read()
old="""def save_formula(i, eq):\n    fig=plt.figure(figsize=(7,1.05),dpi=180)\n    fig.patch.set_alpha(0)\n    ax=fig.add_axes([0,0,1,1]); ax.axis('off')\n    ax.text(0.5,0.5,'$'+eq+'$',ha='center',va='center',fontsize=20)\n    p=ASSETS/f'formula_{i:03d}.png'; fig.savefig(p,transparent=True,bbox_inches='tight',pad_inches=0.12); plt.close(fig); return p\n"""
new="""def save_formula(i, eq):\n    with plt.rc_context({'text.usetex': True, 'text.latex.preamble': r'\\usepackage{amsmath,amssymb}'}):\n        fig=plt.figure(figsize=(7,1.05),dpi=180)\n        fig.patch.set_alpha(0)\n        ax=fig.add_axes([0,0,1,1]); ax.axis('off')\n        ax.text(0.5,0.5,'$'+eq+'$',ha='center',va='center',fontsize=20)\n        p=ASSETS/f'formula_{i:03d}.png'\n        fig.savefig(p,transparent=True,bbox_inches='tight',pad_inches=0.12)\n        plt.close(fig)\n    return p\n"""
if old not in s: print('old not found')
else:
 s=s.replace(old,new)
 open(p,'w').write(s)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
Command failed because it timed out.
Analyzed
bash -lc ls /mnt/data/equation_atlas_1_50/assets/formula_*.png 2>/dev/null | wc -l; ls -lh /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx 2>/dev/null || true; ps aux | grep build_book.py | grep -v grep || true
26
Batch rendering LaTeX formula images
bash -lc python - <<'PY'
import ast
from pathlib import Path
src=Path('/mnt/data/equation_atlas_1_50/build_book.py').read_text()
tree=ast.parse(src)
P=None
for node in tree.body:
    if isinstance(node, ast.Assign) and any(isinstance(t,ast.Name) and t.id=='PAGES' for t in node.targets):
        P=ast.literal_eval(node.value); break
assert P and len(P)==50
tex=[r'\documentclass{article}',r'\usepackage{amsmath,amssymb}',r'\usepackage[paperwidth=7in,paperheight=1.2in,margin=0.08in]{geometry}',r'\pagestyle{empty}',r'\setlength{\parindent}{0pt}',r'\begin{document}']
for idx,row in enumerate(P):
    eq=row[2]
    tex.append(r'\vspace*{\fill}\[\displaystyle '+eq+r'\]\vspace*{\fill}')
    if idx<49: tex.append(r'\newpage')
tex.append(r'\end{document}')
Path('/mnt/data/equation_atlas_1_50/formulas.tex').write_text('\n'.join(tex))
PY
cd /mnt/data/equation_atlas_1_50 && pdflatex -interaction=nonstopmode -halt-on-error formulas.tex >/tmp/formulas.log && pdftocairo -png -r 180 formulas.pdf assets/formula_batch >/tmp/cairo.log
python - <<'PY'
from pathlib import Path
assets=Path('/mnt/data/equation_atlas_1_50/assets')
files=sorted(assets.glob('formula_batch-*.png'))
print('rendered',len(files))
for i,p in enumerate(files,1):
    dest=assets/f'formula_{i:03d}.png'
    dest.write_bytes(p.read_bytes())
print('copied formula pages')
PY
rm -f /mnt/data/equation_atlas_1_50/assets/formula_batch-*.png
ls /mnt/data/equation_atlas_1_50/assets/formula_*.png | wc -l
rendered 50
copied formula pages
50
Analyzed
bash -lc python - <<'PY'
p='/mnt/data/equation_atlas_1_50/build_book.py'
s=open(p).read()
s=s.replace("for i,title,eq,*_ in PAGES:\n    save_formula(i,eq); save_chart(i)\n","for i,title,eq,*_ in PAGES:\n    save_chart(i)\n")
open(p,'w').write(s)
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
ls -lh Equation_Atlas_Pages_1_50.docx
/mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx
-rw-r--r-- 1 root oai_shared 1.7M Aug 23 19:20 Equation_Atlas_Pages_1_50.docx
Analyzed
bash -lc rm -rf /mnt/data/equation_atlas_1_50/rendered/* && python /home/oai/skills/docx/render_docx.py /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx --output_dir /mnt/data/equation_atlas_1_50/rendered --emit_pdf
Pages rendered to /mnt/data/equation_atlas_1_50/rendered
Analyzed
bash -lc ls /mnt/data/equation_atlas_1_50/rendered/page-*.png | wc -l && ls -lh /mnt/data/equation_atlas_1_50/rendered/*.pdf
50
-rw-r--r-- 1 root oai_shared 2.1M Aug 23 19:20 /mnt/data/equation_atlas_1_50/rendered/Equation_Atlas_Pages_1_50.pdf
Generating contact sheets for page inspection
bash -lc python - <<'PY'
from PIL import Image, ImageOps, ImageDraw
from pathlib import Path
root=Path('/mnt/data/equation_atlas_1_50/rendered')
out=root/'contact'; out.mkdir(exist_ok=True)
pages=sorted(root.glob('page-*.png'), key=lambda p:int(p.stem.split('-')[1]))
for batch in range(10):
    imgs=[Image.open(p).convert('RGB') for p in pages[batch*5:(batch+1)*5]]
    # resize each to width 600 for inspection
    ims=[]
    for j,im in enumerate(imgs):
        w=600; h=round(im.height*w/im.width); r=im.resize((w,h))
        canvas=Image.new('RGB',(w+40,h+40),'white'); canvas.paste(r,(20,20));
        d=ImageDraw.Draw(canvas); d.text((24,4),f'Page {batch*5+j+1}',fill='black')
        ims.append(canvas)
    W=sum(x.width for x in ims); H=max(x.height for x in ims)
    sheet=Image.new('RGB',(W,H),'white'); x=0
    for im in ims: sheet.paste(im,(x,0)); x+=im.width
    sheet.save(out/f'contact_{batch+1:02d}.jpg',quality=90)
print('contact sheets',len(list(out.glob('*.jpg'))))
PY
contact sheets 10
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Analyzed
bash -lc python - <<'PY'
from PIL import Image, ImageChops
from pathlib import Path
assets=Path('/mnt/data/equation_atlas_1_50/assets')
for p in sorted(assets.glob('formula_*.png')):
    im=Image.open(p).convert('RGBA')
    # composite on white, detect non-white content including antialiasing
    bg=Image.new('RGBA', im.size, (255,255,255,255))
    comp=Image.alpha_composite(bg,im)
    rgb=comp.convert('RGB')
    # difference from white
    diff=ImageChops.difference(rgb, Image.new('RGB',rgb.size,'white')).convert('L')
    # threshold faint antialiasing
    mask=diff.point(lambda v: 255 if v>8 else 0)
    box=mask.getbbox()
    if box:
        l,t,r,b=box; pad=18
        box=(max(0,l-pad),max(0,t-pad),min(im.width,r+pad),min(im.height,b+pad))
        im=im.crop(box)
        im.save(p)
print('cropped formulas')
PY
cd /mnt/data/equation_atlas_1_50 && python build_book.py
rm -rf rendered/*
python /home/oai/skills/docx/render_docx.py Equation_Atlas_Pages_1_50.docx --output_dir rendered --emit_pdf
ls rendered/page-*.png | wc -l
cropped formulas
/mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx


Command failed because it timed out.
Analyzed
bash -lc ls /mnt/data/equation_atlas_1_50/rendered/page-*.png 2>/dev/null | wc -l; ls -lh /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx; ls -lh /mnt/data/equation_atlas_1_50/rendered/*.pdf 2>/dev/null || true; ps aux | grep render_docx.py | grep -v grep || true
0
-rw-r--r-- 1 root oai_shared 1.7M Aug 23 19:22 /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx
-rw-r--r-- 1 root oai_shared 2.0M Aug 23 19:22 /mnt/data/equation_atlas_1_50/rendered/Equation_Atlas_Pages_1_50.pdf
Analyzed
bash -lc python /home/oai/skills/docx/render_docx.py /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx --output_dir /mnt/data/equation_atlas_1_50/rendered
Pages rendered to /mnt/data/equation_atlas_1_50/rendered
Analyzed
bash -lc ls /mnt/data/equation_atlas_1_50/rendered/page-*.png | wc -l && python - <<'PY'
from PIL import Image, ImageDraw
from pathlib import Path
root=Path('/mnt/data/equation_atlas_1_50/rendered'); out=root/'contact2'; out.mkdir(exist_ok=True)
pages=sorted(root.glob('page-*.png'), key=lambda p:int(p.stem.split('-')[1]))
for batch in [0,7,9]:
 imgs=[]
 for j,p in enumerate(pages[batch*5:(batch+1)*5]):
  im=Image.open(p).convert('RGB'); w=600; h=round(im.height*w/im.width); r=im.resize((w,h)); c=Image.new('RGB',(w+40,h+40),'white'); c.paste(r,(20,20)); ImageDraw.Draw(c).text((24,4),f'Page {batch*5+j+1}',fill='black'); imgs.append(c)
 W=sum(i.width for i in imgs); H=max(i.height for i in imgs); sh=Image.new('RGB',(W,H),'white'); x=0
 for im in imgs: sh.paste(im,(x,0)); x+=im.width
 sh.save(out/f'contact_{batch+1:02d}.jpg',quality=90)
print('made', list(out.glob('*.jpg')))
PY
50
made [PosixPath('/mnt/data/equation_atlas_1_50/rendered/contact2/contact_08.jpg'), PosixPath('/mnt/data/equation_atlas_1_50/rendered/contact2/contact_10.jpg'), PosixPath('/mnt/data/equation_atlas_1_50/rendered/contact2/contact_01.jpg')]
Analyzed image
Output image
Analyzed image
Output image
Analyzed image
Output image
Creating circuit entropy atlas summary
bash -lc cp /mnt/data/equation_atlas_1_50/rendered/Equation_Atlas_Pages_1_50.pdf /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.pdf
python - <<'PY'
from pathlib import Path
import csv,json,numpy as np
import matplotlib.pyplot as plt
root=Path('/mnt/data/equation_atlas_1_50')
rows=list(csv.DictReader((root/'page_circuit_entropy.csv').open()))
states=json.loads((root/'page_circuit_states.json').read_text())
# Human-readable companion atlas
md=['# Page Circuit & Entropy Atlas — Pages 1–50','',
    'Each page uses a deterministic NumPy 3-qubit state-vector circuit with rotation and entangling gates. Entropy is reported as the mean single-qubit von Neumann entropy in bits; the range is obtained by sweeping the page-local parameter interval. Measurement Shannon entropy is also included.','']
for r in rows:
    p=int(r['page']); s=states[str(p)]
    md += [f'## Page {p}',
           f"- Circuit depth: {r['depth']}; topology id: {r['topology_id']}",
           f"- R angle range: [{float(r['R_theta_min']):.6f}, {float(r['R_theta_max']):.6f}] rad",
           f"- G angle range: [{float(r['G_theta_min']):.6f}, {float(r['G_theta_max']):.6f}] rad",
           f"- B angle range: [{float(r['B_theta_min']):.6f}, {float(r['B_theta_max']):.6f}] rad",
           f"- Mean entanglement entropy: {float(r['mean_entanglement_entropy']):.6f} bits",
           f"- Page entropy sweep range: [{float(r['entropy_range_min']):.6f}, {float(r['entropy_range_max']):.6f}] bits",
           f"- Measurement Shannon entropy: {float(r['measurement_shannon_entropy']):.6f} bits",
           '- Circuit sequence: `'+ ' -> '.join(s['ops']) +'`',
           '- Final statevector (real, imag): `'+json.dumps(s['statevector_real_imag'],separators=(',',':'))+'`','']
(root/'Circuit_Entropy_Atlas_1_50.md').write_text('\n'.join(md))
# Overview plot
pages=np.array([int(r['page']) for r in rows])
mean=np.array([float(r['mean_entanglement_entropy']) for r in rows])
lo=np.array([float(r['entropy_range_min']) for r in rows])
hi=np.array([float(r['entropy_range_max']) for r in rows])
fig,ax=plt.subplots(figsize=(10,4.8),dpi=180)
ax.plot(pages,mean,marker='o',ms=3,lw=1.2,label='page state entropy')
ax.fill_between(pages,lo,hi,alpha=.18,label='local sweep range')
ax.set_xlabel('Page'); ax.set_ylabel('Mean single-qubit entropy (bits)')
ax.set_title('Pages 1–50: Circuit-State Entropy and Local Range')
ax.grid(True,alpha=.2); ax.spines['top'].set_visible(False); ax.spines['right'].set_visible(False); ax.legend(frameon=False)
fig.tight_layout(); fig.savefig(root/'Circuit_Entropy_Overview_1_50.png'); plt.close(fig)
# verify states, row counts and ranges
assert len(rows)==50 and len(states)==50
for r in rows:
    p=str(int(r['page'])); arr=np.array([complex(a,b) for a,b in states[p]['statevector_real_imag']])
    assert abs(np.linalg.norm(arr)-1)<1e-9
    for k in ['entropy_R','entropy_G','entropy_B','mean_entanglement_entropy','entropy_range_min','entropy_range_max']:
        v=float(r[k]); assert -1e-9<=v<=1+1e-9
    assert float(r['entropy_range_min'])<=float(r['mean_entanglement_entropy'])+0.2
print('verified 50 normalized states and entropy ranges')
PY
pdfinfo /mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.pdf | grep Pages
cd /mnt/data/equation_atlas_1_50 && zip -q Equation_Atlas_1_50_Package.zip Equation_Atlas_Pages_1_50.docx Equation_Atlas_Pages_1_50.pdf quantum_rgb_page_circuits.py page_circuit_entropy.csv page_circuit_states.json page_entropy_sweeps.npz Circuit_Entropy_Atlas_1_50.md Circuit_Entropy_Overview_1_50.png build_book.py
ls -lh Equation_Atlas_1_50_Package.zip Circuit_Entropy_Atlas_1_50.md Circuit_Entropy_Overview_1_50.png
verified 50 normalized states and entropy ranges
Title:           The Equation Atlas of Advanced AI — Pages 1–50
Pages:           50
-rw-r--r-- 1 root oai_shared  70K Aug 23 19:24 Circuit_Entropy_Atlas_1_50.md
-rw-r--r-- 1 root oai_shared 190K Aug 23 19:24 Circuit_Entropy_Overview_1_50.png
-rw-r--r-- 1 root oai_shared 3.3M Aug 23 19:24 Equation_Atlas_1_50_Package.zip
Worked for 10m 44s
DoneCompleted **Pages 1–50** as a fixed 50-page, 6×9 KDP-oriented manuscript. Each page contains one of equations 1–50, explanation, advanced-AI interpretation, a purpose-built mathematical graph, and an image-generation prompt for artwork to be created later.

The companion simulation layer contains **50 distinct NumPy state-vector circuits** with PennyLane-style rotations and entangling operations. Every page has its own circuit topology/parameters, R/G/B parameter intervals, normalized 8-amplitude statevector, three subsystem entropy measurements, mean single-qubit von Neumann entropy, local swept entropy minimum/maximum, and measurement Shannon entropy. The 50 states and ranges were numerically verified.

* [Download the complete Pages 1–50 package](sandbox:/mnt/data/equation_atlas_1_50/Equation_Atlas_1_50_Package.zip)
* [Kindle/KDP manuscript — DOCX](sandbox:/mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.docx)
* [50-page rendered preview — PDF](sandbox:/mnt/data/equation_atlas_1_50/Equation_Atlas_Pages_1_50.pdf)
* [NumPy circuit interpreter/source](sandbox:/mnt/data/equation_atlas_1_50/quantum_rgb_page_circuits.py)
* [All 50 page parameters + entropy ranges — CSV](sandbox:/mnt/data/equation_atlas_1_50/page_circuit_entropy.csv)
* [Full circuit sequences, statevectors, and entropy atlas](sandbox:/mnt/data/equation_atlas_1_50/Circuit_Entropy_Atlas_1_50.md)
* [50-page entropy-range overview graph](sandbox:/mnt/data/equation_atlas_1_50/Circuit_Entropy_Overview_1_50.png)
* [Complete statevectors — JSON](sandbox:/mnt/data/equation_atlas_1_50/page_circuit_states.json)
* [81-point entropy sweeps for every page — NPZ](sandbox:/mnt/data/equation_atlas_1_50/page_entropy_sweeps.npz)

The manuscript itself keeps the underlying circuit-driven composition machinery out of the visible prose, as requested. The artwork has **not** been generated yet; only the detailed prompts are embedded so the final 500-page book can receive a visually consistent image-generation pass afterward.

The next segment can continue directly with **Pages 51–100**, while generating a new distinct circuit/state/entropy range for every page.
<img src="https://chatgpt.com/backend-api/estuary/content?id=file_00000000fe6c81f68b63b4b5a9968e1a&amp;fn=Circuit_Entropy_Overview_1_50.png&amp;cd=attachment&amp;ts=496532&amp;p=fs&amp;cid=1&amp;sig=1e8e1a92c526cdbf5998c99e63d63f16dcbaea6c2fa0f240b2d8e89c4082f868&amp;v=0" alt="Circuit_Entropy_Overview_1_50.png"/>

Page Circuit & Entropy Atlas — Pages 1–50

Each page uses a deterministic NumPy 3-qubit state-vector circuit with rotation and entangling gates. Entropy is reported as the mean single-qubit von Neumann entropy in bits; the range is obtained by sweeping the page-local parameter interval. Measurement Shannon entropy is also included.

Page 1

Circuit depth: 3; topology id: 1

R angle range: [4.163328, 4.495328] rad

G angle range: [4.270553, 4.512913] rad

B angle range: [1.980929, 2.117049] rad

Mean entanglement entropy: 0.669252 bits

Page entropy sweep range: [0.656223, 0.673984] bits

Measurement Shannon entropy: 2.664470 bits

Circuit sequence: RX(R_theta*1.00+0.030, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.060, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.090, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.030, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+0.060, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RX(B_theta*1.07+0.090, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+0.030, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RX(G_theta*1.14+0.060, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+0.090, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))

Final statevector (real, imag): [[0.08215028573141062,-0.2632583010222168],[-0.23495876989421938,0.11902553774380417],[0.3648432967549003,0.013172658798809658],[-0.05856022773887716,-0.017705606430678398],[-0.4466265501571738,-0.11718914342071438],[0.20309885246415343,0.3954788657535794],[0.1171642621778039,0.23572982196547002],[0.1732812151962673,-0.45537140424779265]]

Page 2

Circuit depth: 4; topology id: 2

R angle range: [1.757365, 2.101365] rad

G angle range: [0.382951, 0.634071] rad

B angle range: [0.138167, 0.279207] rad

Mean entanglement entropy: 0.837931 bits

Page entropy sweep range: [0.798035, 0.924212] bits

Measurement Shannon entropy: 2.350784 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+0.060, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.120, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.180, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.060, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RX(G_theta*1.07+0.120, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+0.180, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+0.060, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RY(G_theta*1.14+0.120, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+0.180, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+0.060, wire=0) -> RZ(R_phi*0.85+0.114, wire=0) -> RY(G_theta*1.21+0.120, wire=1) -> RZ(G_phi*0.85+0.114, wire=1) -> RX(B_theta*1.21+0.180, wire=2) -> RZ(B_phi*0.85+0.114, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[-0.11796987439331745,0.06437615210625526],[-0.11018222912560635,0.18553771549845324],[0.362397282149876,-0.4335387246864643],[-0.09225808131820962,0.25727753602582487],[0.21539581311461348,0.05002512955479995],[-0.12091099286603595,-0.026176457314541074],[0.1273367334430691,0.35584685632303337],[0.2990675581878218,0.49487167433254003]]

Page 3

Circuit depth: 2; topology id: 3

R angle range: [5.634587, 5.990587] rad

G angle range: [2.778534, 3.038414] rad

B angle range: [4.578590, 4.724550] rad

Mean entanglement entropy: 0.660912 bits

Page entropy sweep range: [0.649682, 0.663149] bits

Measurement Shannon entropy: 1.195072 bits

Circuit sequence: RY(R_theta*1.00+0.090, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.180, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.270, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+0.090, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+0.180, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+0.270, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[-0.204132289301218,-0.5196575246032342],[-0.05556185306886879,-0.05518030127519474],[-0.05436448498044179,0.004272913514858527],[0.37636839886267415,-0.7097247990101252],[-0.0886651118592839,0.012698034761078371],[0.008202014195222075,-0.004525295132404912],[-0.0026082736235056077,0.004077270117407577],[0.1555354064972865,0.03863521755105217]]

Page 4

Circuit depth: 3; topology id: 0

R angle range: [3.228624, 3.596624] rad

G angle range: [5.174117, 5.442757] rad

B angle range: [2.735828, 2.886708] rad

Mean entanglement entropy: 0.370704 bits

Page entropy sweep range: [0.339020, 0.464061] bits

Measurement Shannon entropy: 0.856935 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+0.120, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.240, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.360, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.120, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+0.240, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RX(B_theta*1.07+0.360, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+0.120, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RX(G_theta*1.14+0.240, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+0.360, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))

Final statevector (real, imag): [[0.04924110771597186,-0.03135766596992204],[-0.06333881823280778,-0.17345127249724776],[-0.0879225117184581,0.07281873730752755],[0.008840814894040249,0.012245466078518792],[0.16450246179968203,0.9139212626847177],[-0.11815558168947021,0.017842382283159965],[0.04137755132395775,-0.06968674881325908],[0.1797831885630638,0.18371512249521701]]

Page 5

Circuit depth: 4; topology id: 1

R angle range: [0.822661, 1.202661] rad

G angle range: [1.286515, 1.563915] rad

B angle range: [0.893065, 1.048865] rad

Mean entanglement entropy: 0.576989 bits

Page entropy sweep range: [0.453101, 0.687946] bits

Measurement Shannon entropy: 2.227749 bits

Circuit sequence: RY(R_theta*1.00+0.150, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.300, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.450, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.150, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RX(G_theta*1.07+0.300, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+0.450, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+0.150, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RY(G_theta*1.14+0.300, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+0.450, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+0.150, wire=0) -> RZ(R_phi*0.85+0.285, wire=0) -> RY(G_theta*1.21+0.300, wire=1) -> RZ(G_phi*0.85+0.285, wire=1) -> RX(B_theta*1.21+0.450, wire=2) -> RZ(B_phi*0.85+0.285, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[-0.2733494185453167,-0.04974369911491269],[-0.040886646975410695,0.1923445286588644],[0.16380124679706273,-0.11865809743365972],[0.2860961679892602,0.1115273711934313],[0.12852064834023885,-0.6808275679940757],[-0.024646638683942467,0.010288678188338845],[0.329115015441531,0.29504141393240585],[0.13062438082478656,0.23611788050279212]]

Page 6

Circuit depth: 2; topology id: 2

R angle range: [4.699883, 5.091883] rad

G angle range: [3.682099, 3.968259] rad

B angle range: [5.333488, 5.494208] rad

Mean entanglement entropy: 0.498569 bits

Page entropy sweep range: [0.321792, 0.649897] bits

Measurement Shannon entropy: 1.915784 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+0.180, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.360, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.540, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+0.180, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+0.360, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+0.540, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[-0.5979263508892921,-0.014583207327650009],[0.05284578601238683,0.03856400195755954],[0.09534751608347222,-0.6209072168320461],[0.0015225171704476973,-0.018961978259287738],[-0.3222605999339648,-0.22775617740647303],[0.080991256555285,0.03675165885156087],[0.04531886038223628,0.2502180309061855],[-0.11754228164681435,0.0299777494077412]]

Page 7

Circuit depth: 3; topology id: 3

R angle range: [2.293919, 2.697919] rad

G angle range: [6.077682, 6.372602] rad

B angle range: [3.490726, 3.656366] rad

Mean entanglement entropy: 0.387381 bits

Page entropy sweep range: [0.241891, 0.676768] bits

Measurement Shannon entropy: 2.172028 bits

Circuit sequence: RX(R_theta*1.00+0.210, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.420, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.630, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.210, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+0.420, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RX(B_theta*1.07+0.630, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+0.210, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RX(G_theta*1.14+0.420, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+0.630, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))

Final statevector (real, imag): [[0.06403202442498433,-0.10665763296246461],[-0.1416880337076123,0.0917638754997921],[0.05542834547326545,-0.1396629923378611],[-0.03179706772684073,0.0760194501336228],[-0.09013467198529304,0.29785965193703545],[0.5121258106654039,0.002112978243822783],[-0.3774693823500353,0.04013165657665274],[-0.3551523084357684,0.5452624043335795]]

Page 8

Circuit depth: 4; topology id: 0

R angle range: [-0.112044, 0.303956] rad

G angle range: [2.190080, 2.493760] rad

B angle range: [1.647963, 1.818523] rad

Mean entanglement entropy: 0.315411 bits

Page entropy sweep range: [0.073246, 0.538718] bits

Measurement Shannon entropy: 1.765400 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+0.240, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.480, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.720, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.240, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RX(G_theta*1.07+0.480, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+0.720, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+0.240, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RY(G_theta*1.14+0.480, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+0.720, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+0.240, wire=0) -> RZ(R_phi*0.85+0.057, wire=0) -> RY(G_theta*1.21+0.480, wire=1) -> RZ(G_phi*0.85+0.057, wire=1) -> RX(B_theta*1.21+0.720, wire=2) -> RZ(B_phi*0.85+0.057, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[0.5018557186937446,0.10246337337700087],[0.7536428259969581,0.011705078805993531],[-0.15625148960975602,0.10395626627014351],[-0.09021986972532779,0.07865573361918807],[-0.07599353006921979,-0.1909742970110439],[-0.09436616731938127,-0.005233796919205371],[0.04273129959932109,0.03622982050150976],[0.2559592423500481,-0.012146256959093191]]

Page 9

Circuit depth: 2; topology id: 1

R angle range: [3.765178, 4.193178] rad

G angle range: [4.585663, 4.898103] rad

B angle range: [6.088386, 6.263866] rad

Mean entanglement entropy: 0.806157 bits

Page entropy sweep range: [0.759467, 0.849760] bits

Measurement Shannon entropy: 2.198550 bits

Circuit sequence: RY(R_theta*1.00+0.270, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.540, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.810, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+0.270, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+0.540, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+0.810, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[0.6639563360862218,0.08360286765872682],[0.14238459477578183,-0.1994226719667441],[-0.1601344059736584,-0.009877605148079144],[-0.40578217703746206,-0.07657047764146604],[-0.0033829419947420426,0.06632430079085913],[-0.14006601661790494,-0.4402717631896599],[-0.1766123569619165,0.15579565990490168],[-0.1500570129710981,0.004191657780070822]]

Page 10

Circuit depth: 3; topology id: 2

R angle range: [1.359215, 1.799215] rad

G angle range: [0.698061, 1.019261] rad

B angle range: [4.245624, 4.426024] rad

Mean entanglement entropy: 0.806404 bits

Page entropy sweep range: [0.751572, 0.913926] bits

Measurement Shannon entropy: 2.766895 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+0.300, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.600, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.900, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.300, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+0.600, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RX(B_theta*1.07+0.900, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+0.300, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RX(G_theta*1.14+0.600, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+0.900, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))

Final statevector (real, imag): [[-0.0531885504356579,0.3886248665131007],[-0.49356569866705197,-0.1367062564121902],[0.09790589138427255,-0.3768731450982783],[0.39686694865872735,0.10508176866033474],[0.24346117873759898,0.2172812835116918],[0.14882667232088448,-0.23018553578323445],[0.11581881456729787,0.1339773830591038],[0.20357030848071533,-0.09621558715729148]]

Page 11

Circuit depth: 4; topology id: 3

R angle range: [5.302437, 5.622437] rad

G angle range: [3.141824, 3.375424] rad

B angle range: [2.429922, 2.561122] rad

Mean entanglement entropy: 0.360158 bits

Page entropy sweep range: [0.295450, 0.453970] bits

Measurement Shannon entropy: 2.551097 bits

Circuit sequence: RY(R_theta*1.00+0.330, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.660, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.990, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.330, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RX(G_theta*1.07+0.660, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+0.990, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+0.330, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RY(G_theta*1.14+0.660, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+0.990, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+0.330, wire=0) -> RZ(R_phi*0.85+0.228, wire=0) -> RY(G_theta*1.21+0.660, wire=1) -> RZ(G_phi*0.85+0.228, wire=1) -> RX(B_theta*1.21+0.990, wire=2) -> RZ(B_phi*0.85+0.228, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[-0.41054586981303887,-0.04422082117765684],[0.198934674029486,-0.23756551361524675],[-0.44952669255497824,0.26043143624207743],[0.43173239006508957,-0.29002396945580483],[0.13485075423576687,-0.21869045909503562],[-0.12073828677716456,0.16135135191205657],[0.25032462965066604,-0.14387623092743582],[-0.03576071129746077,0.04260089421099058]]

Page 12

Circuit depth: 2; topology id: 0

R angle range: [2.896474, 3.228474] rad

G angle range: [5.537407, 5.779767] rad

B angle range: [0.587159, 0.723279] rad

Mean entanglement entropy: 0.778101 bits

Page entropy sweep range: [0.712153, 0.811578] bits

Measurement Shannon entropy: 2.059049 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+0.360, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.720, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.080, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+0.360, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+0.720, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+1.080, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[-0.04094634877332802,-0.07933868280018014],[-0.20518307499571933,0.11331412170237565],[-0.11995064464794293,-0.05179655853334929],[-0.22006053789545577,-0.49579335556278925],[-0.043897067243928826,0.2983258599221025],[-0.22273679961084344,-0.6447154806563312],[-0.09629884111317134,0.20426395348974738],[-0.1216444245922032,-0.0615650344459234]]

Page 13

Circuit depth: 3; topology id: 1

R angle range: [0.490511, 0.834511] rad

G angle range: [1.649805, 1.900925] rad

B angle range: [5.027582, 5.168622] rad

Mean entanglement entropy: 0.520271 bits

Page entropy sweep range: [0.432627, 0.563786] bits

Measurement Shannon entropy: 1.762901 bits

Circuit sequence: RX(R_theta*1.00+0.390, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.780, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.170, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.390, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+0.780, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RX(B_theta*1.07+1.170, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+0.390, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RX(G_theta*1.14+0.780, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+1.170, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))

Final statevector (real, imag): [[-0.1453525284384602,0.1087052699708467],[0.12099711323951116,0.0038424012986504373],[-0.006103088040449083,-0.3886477486509108],[-0.018958405850959467,-0.2491406171072519],[0.18109273256982109,-0.11936006474336633],[-0.035436406136284876,-0.03376980283219376],[-0.12605065530848547,-0.7908990569903772],[0.16601043870920137,0.14310436651730796]]

Page 14

Circuit depth: 4; topology id: 2

R angle range: [4.367733, 4.723733] rad

G angle range: [4.045388, 4.305268] rad

B angle range: [3.184820, 3.330780] rad

Mean entanglement entropy: 0.748197 bits

Page entropy sweep range: [0.641922, 0.846833] bits

Measurement Shannon entropy: 2.689258 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+0.420, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.840, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+1.260, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.420, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RX(G_theta*1.07+0.840, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+1.260, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+0.420, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RY(G_theta*1.14+0.840, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+1.260, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+0.420, wire=0) -> RZ(R_phi*0.85+0.000, wire=0) -> RY(G_theta*1.21+0.840, wire=1) -> RZ(G_phi*0.85+0.000, wire=1) -> RX(B_theta*1.21+1.260, wire=2) -> RZ(B_phi*0.85+0.000, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[0.2139807655064267,0.18619961773985824],[0.28305925265616017,-0.19913788240154076],[-0.09470670256322536,0.034207038661120494],[-0.041562469513699817,-0.4502923294959285],[0.24024308136228512,-0.009150209887587635],[0.42776405429073794,0.2938538721958605],[0.29703281518486235,-0.06531989959445113],[0.13976928736225902,0.3820603494806292]]

Page 15

Circuit depth: 2; topology id: 3

R angle range: [1.961770, 2.329770] rad

G angle range: [0.157786, 0.426426] rad

B angle range: [1.342057, 1.492937] rad

Mean entanglement entropy: 0.497498 bits

Page entropy sweep range: [0.327689, 0.648041] bits

Measurement Shannon entropy: 1.128397 bits

Circuit sequence: RY(R_theta*1.00+0.450, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.900, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.350, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+0.450, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+0.900, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+1.350, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[-0.30240659759213545,-0.096162001272929],[-0.1078588313701522,0.0054819534355317525],[0.030573251522089485,-0.05394460434724826],[0.8164634900249075,0.35314915547770237],[0.0314874263824382,0.03205823441289259],[-0.031062095506164584,-0.0077011826805945625],[0.05468107502433242,0.23773554543992245],[0.16283026392007216,0.05833167694622215]]

Page 16

Circuit depth: 3; topology id: 0

R angle range: [5.838992, 6.218992] rad

G angle range: [2.553370, 2.830770] rad

B angle range: [5.782480, 5.938280] rad

Mean entanglement entropy: 0.540382 bits

Page entropy sweep range: [0.399202, 0.663243] bits

Measurement Shannon entropy: 2.296829 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+0.480, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.960, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.440, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.480, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+0.960, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RX(B_theta*1.07+1.440, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+0.480, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RX(G_theta*1.14+0.960, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+1.440, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))

Final statevector (real, imag): [[-0.26934996004761963,-0.01101530865674963],[-0.4617470556921104,-0.4088574279435584],[0.026328017473351978,-0.27081343659339635],[-0.037493285743759285,-0.546839346202077],[0.009682019618864316,0.14635443919386146],[-0.014610461159800473,-0.18305133734912632],[0.08050004832708559,-0.049693887580927604],[-0.3174060116546186,-0.08689928460056767]]

Page 17

Circuit depth: 4; topology id: 1

R angle range: [3.433028, 3.825028] rad

G angle range: [4.948953, 5.235113] rad

B angle range: [3.939718, 4.100438] rad

Mean entanglement entropy: 0.405656 bits

Page entropy sweep range: [0.405494, 0.480681] bits

Measurement Shannon entropy: 2.428688 bits

Circuit sequence: RY(R_theta*1.00+0.510, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.020, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+1.530, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.510, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RX(G_theta*1.07+1.020, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+1.530, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+0.510, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RY(G_theta*1.14+1.020, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+1.530, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+0.510, wire=0) -> RZ(R_phi*0.85+0.171, wire=0) -> RY(G_theta*1.21+1.020, wire=1) -> RZ(G_phi*0.85+0.171, wire=1) -> RX(B_theta*1.21+1.530, wire=2) -> RZ(B_phi*0.85+0.171, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[-0.1137832896590089,0.5523713328633778],[0.17996957441877784,0.005325243178499152],[-0.35799524426622936,0.015394184202084198],[0.018487331091663544,0.012482512559776083],[0.15974015352845417,-0.5019496143129593],[-0.0706581814547159,0.3566943571803184],[0.2572244260174773,0.055679124828044144],[-0.11483337994157947,0.1687650642138511]]

Page 18

Circuit depth: 2; topology id: 2

R angle range: [1.027065, 1.431065] rad

G angle range: [1.061351, 1.356271] rad

B angle range: [2.096956, 2.262596] rad

Mean entanglement entropy: 0.773200 bits

Page entropy sweep range: [0.687727, 0.795233] bits

Measurement Shannon entropy: 2.047399 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+0.540, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.080, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.620, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+0.540, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+1.080, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+1.620, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[0.08561480512657764,-0.5284328430961495],[0.1056837876660887,-0.21739067506346116],[-0.003143732459672116,0.03353729671843595],[0.009898908439961955,0.2159480486915342],[-0.07712918048193003,-0.06007119638979852],[0.1054763911098393,-0.016124761356093645],[0.650391170375755,0.10467525032061871],[0.2933129255087256,-0.25728213020483853]]

Page 19

Circuit depth: 3; topology id: 3

R angle range: [4.904287, 5.320287] rad

G angle range: [3.456934, 3.760614] rad

B angle range: [0.254193, 0.424753] rad

Mean entanglement entropy: 0.505016 bits

Page entropy sweep range: [0.504335, 0.570352] bits

Measurement Shannon entropy: 1.968713 bits

Circuit sequence: RX(R_theta*1.00+0.570, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.140, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.710, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.570, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+1.140, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RX(B_theta*1.07+1.710, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+0.570, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RX(G_theta*1.14+1.140, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+1.710, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))

Final statevector (real, imag): [[0.013727394831774814,0.03825505312950234],[-0.06803639372191202,0.633024713500392],[-0.32082575092160354,0.22910716578687532],[-0.29279330194837455,-0.5126806016038545],[-0.004939593267422827,0.1725315928242368],[-0.1257287238823725,0.04994605986495418],[0.15364542809215598,0.08616922183612648],[0.09442825639860693,0.031107539135098488]]

Page 20

Circuit depth: 4; topology id: 0

R angle range: [2.498324, 2.926324] rad

G angle range: [5.852517, 6.164957] rad

B angle range: [4.694616, 4.870096] rad

Mean entanglement entropy: 0.638422 bits

Page entropy sweep range: [0.542798, 0.745948] bits

Measurement Shannon entropy: 2.694563 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+0.600, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.200, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+1.800, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.600, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RX(G_theta*1.07+1.200, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+1.800, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+0.600, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RY(G_theta*1.14+1.200, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+1.800, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+0.600, wire=0) -> RZ(R_phi*0.85+0.342, wire=0) -> RY(G_theta*1.21+1.200, wire=1) -> RZ(G_phi*0.85+0.342, wire=1) -> RX(B_theta*1.21+1.800, wire=2) -> RZ(B_phi*0.85+0.342, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[0.27104461086840326,-0.14098793878124677],[-0.3111071653747669,0.21614063498385516],[-0.2777238524865879,0.350780365192016],[0.22004531591307705,0.4889930640204292],[-0.17788263158213274,-0.041429692114299255],[0.22835475335642264,0.2970264957846903],[0.23652592639503195,-0.10072395650829453],[-0.05776402966315526,-0.17968144606091255]]

Page 21

Circuit depth: 2; topology id: 1

R angle range: [0.092361, 0.532361] rad

G angle range: [1.964915, 2.286115] rad

B angle range: [2.851854, 3.032254] rad

Mean entanglement entropy: 0.219292 bits

Page entropy sweep range: [0.168870, 0.324287] bits

Measurement Shannon entropy: 2.064194 bits

Circuit sequence: RY(R_theta*1.00+0.630, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.260, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.890, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+0.630, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+1.260, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+1.890, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[-0.6078821584403411,-0.3315366155499022],[0.4706068498790016,-0.029721944351567525],[0.19312793885517038,-0.12099797342803828],[-0.009024540000969791,0.1021500039362997],[-0.22393106075399039,-0.28554195221941203],[0.06397762137506144,0.2996941726759499],[0.07136581649190746,-0.03423836493300739],[-0.026579313631086492,-0.05650408811444462]]

Page 22

Circuit depth: 3; topology id: 2

R angle range: [4.035583, 4.355583] rad

G angle range: [4.408678, 4.642278] rad

B angle range: [1.036151, 1.167351] rad

Mean entanglement entropy: 0.310182 bits

Page entropy sweep range: [0.093350, 0.523661] bits

Measurement Shannon entropy: 1.720210 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+0.660, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.320, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.980, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.660, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+1.320, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RX(B_theta*1.07+1.980, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+0.660, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RX(G_theta*1.14+1.320, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+1.980, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))

Final statevector (real, imag): [[-0.03894855207664813,0.022473281664554142],[0.44616973781959557,-0.19442933224851222],[0.03937645716905093,0.004857597683842591],[0.039527914061716685,-0.14741058574665483],[-0.014628153616036746,-0.026431824272533846],[-0.11251406760806676,-0.6140725919320003],[0.001077917923934387,-0.0029760770358196703],[0.17227472621814785,-0.5620458480262667]]

Page 23

Circuit depth: 4; topology id: 3

R angle range: [1.629620, 1.961620] rad

G angle range: [0.521076, 0.763436] rad

B angle range: [5.476574, 5.612694] rad

Mean entanglement entropy: 0.420623 bits

Page entropy sweep range: [0.203340, 0.654875] bits

Measurement Shannon entropy: 2.166177 bits

Circuit sequence: RY(R_theta*1.00+0.690, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.380, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.070, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.690, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RX(G_theta*1.07+1.380, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+2.070, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+0.690, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RY(G_theta*1.14+1.380, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+2.070, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+0.690, wire=0) -> RZ(R_phi*0.85+0.114, wire=0) -> RY(G_theta*1.21+1.380, wire=1) -> RZ(G_phi*0.85+0.114, wire=1) -> RX(B_theta*1.21+2.070, wire=2) -> RZ(B_phi*0.85+0.114, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[0.3557957946431965,-0.440572997724811],[0.22519906257296446,-0.020691782525082525],[0.592385829907886,-0.22132255988925986],[0.24543403826853372,0.13250599131898272],[-0.05704965534316776,0.04134901409080754],[0.22151682233782524,-0.1847876641240369],[0.03327546747829338,-0.048578655489646544],[0.1343134871923778,-0.201925292609389]]

Page 24

Circuit depth: 2; topology id: 0

R angle range: [5.506842, 5.850842] rad

G angle range: [2.916659, 3.167779] rad

B angle range: [3.633812, 3.774852] rad

Mean entanglement entropy: 0.937364 bits

Page entropy sweep range: [0.899347, 0.949589] bits

Measurement Shannon entropy: 2.238544 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+0.720, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.440, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.160, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+0.720, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+1.440, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+2.160, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[-0.3974560371386538,0.26977200457830086],[-0.021861337027009643,0.060792485684602764],[0.10320307287810632,-0.08927767124518995],[-0.2804612435012519,-0.3304578226162505],[-0.22038706235349564,0.5283402078657715],[-0.0962642759370259,-0.09761362180541733],[0.02733845664114352,-0.08306025044233044],[0.4445943883572221,0.08231787283837885]]

Page 25

Circuit depth: 3; topology id: 1

R angle range: [3.100878, 3.456878] rad

G angle range: [5.312243, 5.572123] rad

B angle range: [1.791050, 1.937010] rad

Mean entanglement entropy: 0.797964 bits

Page entropy sweep range: [0.732233, 0.857129] bits

Measurement Shannon entropy: 2.271953 bits

Circuit sequence: RX(R_theta*1.00+0.750, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.500, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.250, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.750, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+1.500, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RX(B_theta*1.07+2.250, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+0.750, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RX(G_theta*1.14+1.500, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+2.250, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))

Final statevector (real, imag): [[-0.1925903542785199,-0.18289854287748178],[-0.11710976283527962,0.08781592255319229],[-0.23930114750231296,0.09615592566307533],[6.587213280493524e-05,-0.06723216078851874],[-0.18348070471933567,0.06749394289088852],[-0.0506640997331617,-0.6533305131917938],[-0.10331777062423564,0.3595617802028836],[0.47056330204705554,0.08934376354364297]]

Page 26

Circuit depth: 4; topology id: 2

R angle range: [0.694915, 1.062915] rad

G angle range: [1.424641, 1.693281] rad

B angle range: [-0.051713, 0.099167] rad

Mean entanglement entropy: 0.523312 bits

Page entropy sweep range: [0.456596, 0.604835] bits

Measurement Shannon entropy: 2.133530 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+0.780, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.560, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.340, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.780, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RX(G_theta*1.07+1.560, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+2.340, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+0.780, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RY(G_theta*1.14+1.560, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+2.340, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+0.780, wire=0) -> RZ(R_phi*0.85+0.285, wire=0) -> RY(G_theta*1.21+1.560, wire=1) -> RZ(G_phi*0.85+0.285, wire=1) -> RX(B_theta*1.21+2.340, wire=2) -> RZ(B_phi*0.85+0.285, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[0.16709644292969053,-0.05228234678791192],[0.09693120236187307,-0.1455164215974255],[-0.4691903349064492,0.3731873519179782],[-0.23457235494893638,0.5395827504199501],[-0.15170925614466627,0.26817746435449324],[-0.08173827742107902,0.018279186521218748],[-0.3586627751561407,-0.04085356482177772],[0.008566891065129699,-0.029343255842504266]]

Page 27

Circuit depth: 2; topology id: 3

R angle range: [4.572137, 4.952137] rad

G angle range: [3.820224, 4.097624] rad

B angle range: [4.388710, 4.544510] rad

Mean entanglement entropy: 0.796228 bits

Page entropy sweep range: [0.744016, 0.843507] bits

Measurement Shannon entropy: 1.922887 bits

Circuit sequence: RY(R_theta*1.00+0.810, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.620, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.430, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+0.810, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+1.620, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+2.430, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[-0.7451755060098036,0.007464533249561926],[0.15183978072439552,0.11536573965532547],[0.029844971405751347,-0.23390023832843976],[0.21974907435470042,-0.3801808075422409],[-0.05674657626028861,-0.06278926124526078],[-0.08396572849587575,-0.06859033431320918],[-0.01318620857156253,-0.11421813389453864],[-0.11260356739212166,-0.3391891254358115]]

Page 28

Circuit depth: 3; topology id: 0

R angle range: [2.166174, 2.558174] rad

G angle range: [-0.067378, 0.218782] rad

B angle range: [2.545948, 2.706668] rad

Mean entanglement entropy: 0.249945 bits

Page entropy sweep range: [0.116617, 0.513744] bits

Measurement Shannon entropy: 2.125445 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+0.840, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.680, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.520, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.840, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+1.680, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RX(B_theta*1.07+2.520, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+0.840, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RX(G_theta*1.14+1.680, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+2.520, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))

Final statevector (real, imag): [[0.14879492314957815,0.0138696850640249],[-0.024618490051898298,-0.0899340612814685],[0.05482838599016406,0.07645799820948994],[0.04195486550806949,-0.06014242637128628],[0.14619007561971453,-0.4819164745027543],[0.3008704525344462,0.085977900784991],[-0.2577341207755321,-0.5612020835027713],[0.31948575297441134,-0.34607533938154944]]

Page 29

Circuit depth: 4; topology id: 1

R angle range: [6.043396, 6.447396] rad

G angle range: [2.328205, 2.623125] rad

B angle range: [0.703185, 0.868825] rad

Mean entanglement entropy: 0.886715 bits

Page entropy sweep range: [0.877638, 0.892491] bits

Measurement Shannon entropy: 2.591407 bits

Circuit sequence: RY(R_theta*1.00+0.870, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.740, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.610, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.870, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RX(G_theta*1.07+1.740, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+2.610, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+0.870, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RY(G_theta*1.14+1.740, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+2.610, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+0.870, wire=0) -> RZ(R_phi*0.85+0.057, wire=0) -> RY(G_theta*1.21+1.740, wire=1) -> RZ(G_phi*0.85+0.057, wire=1) -> RX(B_theta*1.21+2.610, wire=2) -> RZ(B_phi*0.85+0.057, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[-0.32996439181364773,0.3885173348102446],[-0.2325809673601992,0.20912442948569887],[0.25350496167646414,-0.03336423311498648],[0.007056877438030603,0.4613507080305072],[0.032743135284527804,0.08129695697172777],[-0.14461020555602122,-0.33293392022302537],[0.18064091374714517,-0.412814957791264],[0.10651648397307603,-0.10122810368155197]]

Page 30

Circuit depth: 2; topology id: 2

R angle range: [3.637433, 4.053433] rad

G angle range: [4.723788, 5.027468] rad

B angle range: [5.143608, 5.314168] rad

Mean entanglement entropy: 0.945941 bits

Page entropy sweep range: [0.890525, 0.957476] bits

Measurement Shannon entropy: 2.184139 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+0.900, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.800, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.700, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+0.900, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+1.800, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+2.700, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[0.23562315442812448,0.10198348719493044],[-0.4143208908357606,0.4031862769313449],[0.05121677733097229,-0.029468036471457855],[-0.28909711142734784,-0.04585427002603241],[-0.19333833894911984,-0.1129926777279098],[0.03062528915941124,0.09512414998933705],[-0.4751628168164951,0.4018793336769445],[-0.05142801064216665,0.2462188725586499]]

Page 31

Circuit depth: 3; topology id: 3

R angle range: [1.231470, 1.659470] rad

G angle range: [0.836186, 1.148626] rad

B angle range: [3.300846, 3.476326] rad

Mean entanglement entropy: 0.829892 bits

Page entropy sweep range: [0.595047, 0.904414] bits

Measurement Shannon entropy: 1.925787 bits

Circuit sequence: RX(R_theta*1.00+0.930, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.860, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.790, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.930, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+1.860, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RX(B_theta*1.07+2.790, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+0.930, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RX(G_theta*1.14+1.860, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+2.790, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))

Final statevector (real, imag): [[0.10841359925427335,0.1036347929069964],[-0.016182954134150936,-0.5309225051207175],[-0.1888321376616991,0.13583165959664914],[-0.08783209684172982,-0.10870216358421494],[0.06495402580503383,-0.7130565225965092],[0.028480194883221614,0.0777086850496482],[-0.013533153367059642,0.13459718655230435],[-0.24523753284179958,0.15416836796469274]]

Page 32

Circuit depth: 4; topology id: 0

R angle range: [5.108692, 5.548692] rad

G angle range: [3.231769, 3.552969] rad

B angle range: [1.458084, 1.638484] rad

Mean entanglement entropy: 0.541351 bits

Page entropy sweep range: [0.336393, 0.686416] bits

Measurement Shannon entropy: 2.401382 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+0.960, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.920, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.880, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.960, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RX(G_theta*1.07+1.920, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+2.880, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+0.960, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RY(G_theta*1.14+1.920, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+2.880, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+0.960, wire=0) -> RZ(R_phi*0.85+0.228, wire=0) -> RY(G_theta*1.21+1.920, wire=1) -> RZ(G_phi*0.85+0.228, wire=1) -> RX(B_theta*1.21+2.880, wire=2) -> RZ(B_phi*0.85+0.228, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[-0.6618628699660212,0.14954563431020948],[-0.2561970469277396,-0.027395883319725478],[-0.2135771847604334,-0.04307100210723147],[-0.1781412418415916,0.17107345308368305],[0.429672113621601,0.0577313955747664],[0.201463029407015,0.1433948315269177],[0.11277906794047007,-0.1815203069108851],[-0.1286461270633378,-0.23107659919103662]]

Page 33

Circuit depth: 2; topology id: 1

R angle range: [2.768729, 3.088729] rad

G angle range: [5.675533, 5.909133] rad

B angle range: [5.925567, 6.056767] rad

Mean entanglement entropy: 0.786296 bits

Page entropy sweep range: [0.716305, 0.838051] bits

Measurement Shannon entropy: 2.483124 bits

Circuit sequence: RY(R_theta*1.00+0.990, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.980, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.970, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+0.990, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+1.980, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+2.970, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[0.3678835838055003,-0.04343565260203333],[0.07426750703512357,-0.11681314741167004],[-0.06137862130558536,-0.3233170909125628],[0.047875121511878505,0.03771236585559614],[0.3861866887384888,-0.10030364019364743],[0.5371761054773513,0.2841313851693279],[-0.11146856656396391,-0.35485925645099337],[-0.09903712429609168,0.23441424076560974]]

Page 34

Circuit depth: 3; topology id: 2

R angle range: [0.362765, 0.694765] rad

G angle range: [1.787931, 2.030291] rad

B angle range: [4.082804, 4.218924] rad

Mean entanglement entropy: 0.579602 bits

Page entropy sweep range: [0.486201, 0.654395] bits

Measurement Shannon entropy: 2.017786 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+1.020, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.040, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.060, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.020, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+2.040, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RX(B_theta*1.07+3.060, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+1.020, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RX(G_theta*1.14+2.040, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+3.060, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))

Final statevector (real, imag): [[-0.318828094504034,-0.5122683494788225],[0.1743626472855628,0.029543869689178624],[0.23840206588098703,-0.13016857945747215],[-0.01543632934425855,0.09080757970296352],[-0.4192482070302956,0.48095133314073935],[-0.07412996999524132,0.13774757777299815],[0.22072236828777947,0.19632776543294256],[0.04986068786827677,0.032999625212173145]]

Page 35

Circuit depth: 4; topology id: 3

R angle range: [4.239987, 4.583987] rad

G angle range: [4.183514, 4.434634] rad

B angle range: [2.240042, 2.381082] rad

Mean entanglement entropy: 0.562603 bits

Page entropy sweep range: [0.432251, 0.646293] bits

Measurement Shannon entropy: 2.118935 bits

Circuit sequence: RY(R_theta*1.00+1.050, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.100, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.150, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+1.050, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RX(G_theta*1.07+2.100, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+3.150, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+1.050, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RY(G_theta*1.14+2.100, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+3.150, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+1.050, wire=0) -> RZ(R_phi*0.85+0.000, wire=0) -> RY(G_theta*1.21+2.100, wire=1) -> RZ(G_phi*0.85+0.000, wire=1) -> RX(B_theta*1.21+3.150, wire=2) -> RZ(B_phi*0.85+0.000, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[0.6862110858891266,-0.2208801357647304],[-0.02902528370778629,-0.18916363426657956],[-0.3017069146623537,-0.30814396119036136],[-0.1860652083432906,-0.017845939844618033],[-0.22429418980483024,0.027994941704096603],[-0.1145579717152521,0.014840269669703091],[-0.35017595981342964,0.07927384467702067],[-0.11192716448079137,-0.1300456183336547]]

Page 36

Circuit depth: 2; topology id: 0

R angle range: [1.834024, 2.190024] rad

G angle range: [0.295912, 0.555792] rad

B angle range: [0.397279, 0.543239] rad

Mean entanglement entropy: 0.883924 bits

Page entropy sweep range: [0.820352, 0.906263] bits

Measurement Shannon entropy: 1.927572 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+1.080, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.160, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.240, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+1.080, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+2.160, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+3.240, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[0.31169165308413094,0.027654176589821004],[-0.08994759665969759,0.037202746705303366],[-0.022115603002113023,0.0035399498741491525],[-0.38250165562159305,0.5073977601495498],[-0.5890083560231424,0.03345171860564312],[0.34693556348435983,-0.08267588137836804],[0.021101561218171333,-0.09323889369332075],[-0.03453327959049147,-0.05259799056350032]]

Page 37

Circuit depth: 3; topology id: 1

R angle range: [5.711246, 6.079246] rad

G angle range: [2.691495, 2.960135] rad

B angle range: [4.837702, 4.988582] rad

Mean entanglement entropy: 0.377750 bits

Page entropy sweep range: [0.362800, 0.478058] bits

Measurement Shannon entropy: 1.736532 bits

Circuit sequence: RX(R_theta*1.00+1.110, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.220, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.330, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+1.110, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+2.220, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RX(B_theta*1.07+3.330, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+1.110, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RX(G_theta*1.14+2.220, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+3.330, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))

Final statevector (real, imag): [[0.29395346723807253,0.20085180045998596],[-0.026229299342121662,0.0016879300548389713],[0.458687843895008,-0.28389873050354625],[0.7109442047299931,-0.10790643257076868],[0.058887411919467184,-0.06484152510254887],[-0.0063136283774273775,-0.0378821508383026],[0.12867962839592975,0.16240029765563324],[0.027537592101471838,0.10790230773175676]]

Page 38

Circuit depth: 4; topology id: 2

R angle range: [3.305283, 3.685283] rad

G angle range: [5.087078, 5.364478] rad

B angle range: [2.994940, 3.150740] rad

Mean entanglement entropy: 0.847374 bits

Page entropy sweep range: [0.847302, 0.852384] bits

Measurement Shannon entropy: 2.523776 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+1.140, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.280, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.420, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.140, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RX(G_theta*1.07+2.280, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+3.420, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+1.140, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RY(G_theta*1.14+2.280, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+3.420, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+1.140, wire=0) -> RZ(R_phi*0.85+0.171, wire=0) -> RY(G_theta*1.21+2.280, wire=1) -> RZ(G_phi*0.85+0.171, wire=1) -> RX(B_theta*1.21+3.420, wire=2) -> RZ(B_phi*0.85+0.171, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[0.3293375165337459,-0.035278159340758786],[0.09885901582587112,0.08927190017426176],[0.4320805502491575,-0.12409605566543105],[-0.5761054841027096,-0.10562298241349011],[0.16952093260991513,0.21473307228195726],[0.3776374769778471,-0.15464433369295433],[0.1595438636663491,-0.21066188724233487],[0.04411683742741683,-0.119377363611607]]

Page 39

Circuit depth: 2; topology id: 3

R angle range: [0.899320, 1.291320] rad

G angle range: [1.199476, 1.485636] rad

B angle range: [1.152178, 1.312898] rad

Mean entanglement entropy: 0.480264 bits

Page entropy sweep range: [0.447700, 0.529613] bits

Measurement Shannon entropy: 2.040700 bits

Circuit sequence: RY(R_theta*1.00+1.170, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.340, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.510, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+1.170, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+2.340, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+3.510, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[0.2113691610717028,-0.1869655019527719],[-0.003274645990314351,0.4082988913657975],[-0.050731336003699015,-0.11710295621801367],[-0.5435153466707144,0.16666679634730822],[-0.02960610665155846,0.022357796072440823],[0.01952312278510592,0.1417273891273431],[-0.06673666629061971,0.02186002776730647],[-0.4670880344059445,0.4113729133964868]]

Page 40

Circuit depth: 3; topology id: 0

R angle range: [4.776542, 5.180542] rad

G angle range: [3.595059, 3.889979] rad

B angle range: [5.592601, 5.758241] rad

Mean entanglement entropy: 0.817656 bits

Page entropy sweep range: [0.797383, 0.823652] bits

Measurement Shannon entropy: 1.912529 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+1.200, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.400, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.600, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+1.200, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+2.400, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RX(B_theta*1.07+3.600, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+1.200, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RX(G_theta*1.14+2.400, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+3.600, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))

Final statevector (real, imag): [[-0.22071302483580318,-0.13393366114679003],[-0.6284380261864536,0.16767450776761764],[0.44227281171117705,-0.4188347542619627],[0.04019158373412288,0.0034491216365604826],[0.09888668645640235,0.21348763236385215],[0.00596738971094887,-0.02044927229186986],[0.07520220294829992,-0.08059336621398852],[0.00993584167140081,0.2637890809038934]]

Page 41

Circuit depth: 4; topology id: 1

R angle range: [2.370579, 2.786579] rad

G angle range: [5.990643, 6.294323] rad

B angle range: [3.749838, 3.920398] rad

Mean entanglement entropy: 0.558131 bits

Page entropy sweep range: [0.395090, 0.670627] bits

Measurement Shannon entropy: 2.524022 bits

Circuit sequence: RY(R_theta*1.00+1.230, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.460, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.690, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+1.230, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RX(G_theta*1.07+2.460, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+3.690, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+1.230, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RY(G_theta*1.14+2.460, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+3.690, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+1.230, wire=0) -> RZ(R_phi*0.85+0.342, wire=0) -> RY(G_theta*1.21+2.460, wire=1) -> RZ(G_phi*0.85+0.342, wire=1) -> RX(B_theta*1.21+3.690, wire=2) -> RZ(B_phi*0.85+0.342, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[-0.1518775771913618,-0.6017037637192294],[0.11828233756040685,-0.23346797453809645],[-0.1247957371908958,-0.14683589755317422],[-0.049419761302452264,-0.24861073588496585],[0.36687212895997096,0.1472613583747209],[-0.2214810901342767,0.3721065063132967],[0.0014780905113766373,-0.18191006792662226],[0.21824466987412877,-0.1431119234178596]]

Page 42

Circuit depth: 2; topology id: 2

R angle range: [-0.035385, 0.392615] rad

G angle range: [2.103040, 2.415480] rad

B angle range: [1.907076, 2.082556] rad

Mean entanglement entropy: 0.766807 bits

Page entropy sweep range: [0.736555, 0.768429] bits

Measurement Shannon entropy: 2.415923 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+1.260, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.520, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.780, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+1.260, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+2.520, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+3.780, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[0.437404443072463,0.13884160476135282],[0.06880451284738073,0.057461366405570986],[0.17081085174315538,-0.4062460550049493],[-0.19567784488777354,-0.009310547963282113],[-0.3454357276606322,0.3451865991104112],[-0.0724403872521666,0.06184368172533838],[-0.23836252707949782,-0.4518615741029742],[-0.1573845284466521,0.12433195768363663]]

Page 43

Circuit depth: 3; topology id: 3

R angle range: [3.841838, 4.281838] rad

G angle range: [4.498624, 4.819824] rad

B angle range: [0.064314, 0.244714] rad

Mean entanglement entropy: 0.806398 bits

Page entropy sweep range: [0.662464, 0.807491] bits

Measurement Shannon entropy: 2.554865 bits

Circuit sequence: RX(R_theta*1.00+1.290, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.580, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.870, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+1.290, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+2.580, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RX(B_theta*1.07+3.870, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+1.290, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RX(G_theta*1.14+2.580, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+3.870, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))

Final statevector (real, imag): [[0.12909068553071043,0.1486921013568166],[-0.4269918657455097,-0.33811657651404314],[0.13535242750799228,-0.1856676779559604],[-0.1941571444339048,-0.45346067197406137],[0.27799128813433105,0.03852179840848473],[0.12417919196543079,0.2353741354010447],[-0.13647979805429905,0.023493439080605104],[-0.32506141747513034,-0.3066543567165398]]

Page 44

Circuit depth: 4; topology id: 0

R angle range: [1.501874, 1.821874] rad

G angle range: [0.659202, 0.892802] rad

B angle range: [4.531796, 4.662996] rad

Mean entanglement entropy: 0.120258 bits

Page entropy sweep range: [0.109249, 0.224013] bits

Measurement Shannon entropy: 1.576087 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+1.320, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.640, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.960, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+1.320, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RX(G_theta*1.07+2.640, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+3.960, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+1.320, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RY(G_theta*1.14+2.640, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+3.960, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+1.320, wire=0) -> RZ(R_phi*0.85+0.114, wire=0) -> RY(G_theta*1.21+2.640, wire=1) -> RZ(G_phi*0.85+0.114, wire=1) -> RX(B_theta*1.21+3.960, wire=2) -> RZ(B_phi*0.85+0.114, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[0.2958715925621255,0.4419655914360766],[0.42707114757157916,0.6263391832671067],[0.008602909525837312,-0.29611260426325803],[0.02218413252853012,-0.19528895900532828],[0.00578199431454354,0.01573105176939959],[-0.08584804804467502,-0.06551290765405787],[-0.01826980663868467,0.0593868606390824],[-0.008949507976647382,0.01287931681388984]]

Page 45

Circuit depth: 2; topology id: 1

R angle range: [5.379096, 5.711096] rad

G angle range: [3.054785, 3.297145] rad

B angle range: [2.689034, 2.825154] rad

Mean entanglement entropy: 0.479784 bits

Page entropy sweep range: [0.411992, 0.545560] bits

Measurement Shannon entropy: 1.515252 bits

Circuit sequence: RY(R_theta*1.00+1.350, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.700, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.050, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+1.350, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+2.700, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+4.050, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=0)

Final statevector (real, imag): [[0.6985557222308186,0.4108490662410412],[-0.06856442859094364,-0.0012830826806931248],[0.020960944062875235,-0.008580252565345541],[0.12863719196447304,0.012997470611121976],[0.36612952700935397,0.11854646300951541],[-0.09112787782392825,-0.3660023049768788],[-0.002155617855464864,-0.050898052330119806],[0.005163464118654884,0.16823431767361952]]

Page 46

Circuit depth: 3; topology id: 2

R angle range: [2.973133, 3.317133] rad

G angle range: [5.450368, 5.701488] rad

B angle range: [0.846272, 0.987312] rad

Mean entanglement entropy: 0.714351 bits

Page entropy sweep range: [0.614714, 0.805470] bits

Measurement Shannon entropy: 2.743970 bits

Circuit sequence: H(wire=1) -> RX(R_theta*1.00+1.380, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.760, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.140, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.380, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+2.760, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RX(B_theta*1.07+4.140, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+1.380, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RX(G_theta*1.14+2.760, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+4.140, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))

Final statevector (real, imag): [[0.16079699254400345,0.32723586827091994],[0.30188893202955175,0.012713471822393633],[-0.1616142442055241,-0.5285914156331382],[-0.315387320420773,-0.18694757389569736],[-0.1693583253352007,0.23825897270186655],[0.17461013584702384,0.05303593932937276],[-0.22754377042492835,0.3242676274255163],[0.24264079792313256,-0.035560355351295724]]

Page 47

Circuit depth: 4; topology id: 3

R angle range: [0.567170, 0.923170] rad

G angle range: [1.562766, 1.822646] rad

B angle range: [5.286695, 5.432655] rad

Mean entanglement entropy: 0.826968 bits

Page entropy sweep range: [0.648960, 0.872916] bits

Measurement Shannon entropy: 2.797420 bits

Circuit sequence: RY(R_theta*1.00+1.410, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.820, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+4.230, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+1.410, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RX(G_theta*1.07+2.820, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+4.230, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+1.410, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RY(G_theta*1.14+2.820, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+4.230, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+1.410, wire=0) -> RZ(R_phi*0.85+0.285, wire=0) -> RY(G_theta*1.21+2.820, wire=1) -> RZ(G_phi*0.85+0.285, wire=1) -> RX(B_theta*1.21+4.230, wire=2) -> RZ(B_phi*0.85+0.285, wire=2) -> CNOT(control=2, target=1)

Final statevector (real, imag): [[0.035596736804003944,-0.17800769406614972],[0.1668113977303578,0.2977585308573332],[0.49663878967838,-0.09427395032939341],[0.0233638192506702,-0.348823233049827],[0.4128459819009097,0.08554953575691554],[-0.22280132818172227,0.02096455428220552],[-0.16299828097609137,0.29333877163451183],[-0.10411480545538776,-0.34857183980622847]]

Page 48

Circuit depth: 2; topology id: 0

R angle range: [4.444392, 4.812392] rad

G angle range: [3.958349, 4.226989] rad

B angle range: [3.443932, 3.594812] rad

Mean entanglement entropy: 0.587174 bits

Page entropy sweep range: [0.517552, 0.661080] bits

Measurement Shannon entropy: 2.629119 bits

Circuit sequence: H(wire=0) -> RY(R_theta*1.00+1.440, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.880, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.320, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+1.440, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+2.880, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+4.320, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=1, target=2)

Final statevector (real, imag): [[0.09399372917907538,0.34611357663798475],[-0.4979398677617136,-0.2729466257561151],[-0.12826071233486133,0.3158750579763281],[-0.1461771800170476,-0.20895321705295541],[-0.18735788142613144,-0.04107472446758092],[-0.2135723612703092,-0.1263978134050254],[-0.1295999873060505,-0.1637970813874687],[-0.020703521374626558,-0.4745899021641173]]

Page 49

Circuit depth: 3; topology id: 1

R angle range: [2.038429, 2.418429] rad

G angle range: [0.070747, 0.348147] rad

B angle range: [1.601170, 1.756970] rad

Mean entanglement entropy: 0.007052 bits

Page entropy sweep range: [0.002841, 0.123829] bits

Measurement Shannon entropy: 1.111864 bits

Circuit sequence: RX(R_theta*1.00+1.470, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.940, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.410, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+1.470, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+2.940, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RX(B_theta*1.07+4.410, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+1.470, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RX(G_theta*1.14+2.940, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+4.410, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))

Final statevector (real, imag): [[-0.0025419433175485847,-0.0003124646780419727],[-0.0053827331542641,0.0035205963988822896],[0.02114329090820458,-0.7229385924327696],[0.04081187496026025,-0.05619401865113885],[0.0020427623006829647,0.003800834780640077],[0.004651003629034902,0.00395350875534964],[0.654366079836303,-0.18231026278122334],[0.09949297717092143,0.025587424150077056]]

Page 50

Circuit depth: 4; topology id: 2

R angle range: [5.915651, 6.307651] rad

G angle range: [2.466330, 2.752490] rad

B angle range: [6.041593, 6.202313] rad

Mean entanglement entropy: 0.703723 bits

Page entropy sweep range: [0.599533, 0.783681] bits

Measurement Shannon entropy: 2.201197 bits

Circuit sequence: H(wire=2) -> RY(R_theta*1.00+1.500, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+3.000, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+4.500, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.500, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RX(G_theta*1.07+3.000, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+4.500, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+1.500, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RY(G_theta*1.14+3.000, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+4.500, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+1.500, wire=0) -> RZ(R_phi*0.85+0.057, wire=0) -> RY(G_theta*1.21+3.000, wire=1) -> RZ(G_phi*0.85+0.057, wire=1) -> RX(B_theta*1.21+4.500, wire=2) -> RZ(B_phi*0.85+0.057, wire=2) -> CNOT(control=0, target=1)

Final statevector (real, imag): [[-0.036578042097792786,-0.00823031123279786],[-0.3139484171521342,-0.11259744538803289],[-0.24819847136318632,0.11734187786287911],[0.28123455443352613,0.03533314760144854],[-0.4653503967703059,-0.4430715187560579],[0.09754770925590833,-0.11760192696483379],[-0.12045532112930049,0.5149074531202503],[0.12260265021818946,-0.027566306193165697]]