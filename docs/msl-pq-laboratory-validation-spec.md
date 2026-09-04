# MSL-PQ Laboratory Characterization and Security Validation Specification

**Document ID:** NAZA-MSL-LAB-001  
**Revision:** 0.1 (engineering baseline)  
**Status:** Pre-certification research specification  
**Applies to:** `MSL-PQ/host-v2`, physical surfaces, optical readers, firmware,
enrollment tooling, helper-data construction, reader attestation, and hybrid
ML-KEM session binding

## 1. Purpose and claim boundary

This specification defines the evidence required before a Metameric Surface
Lattice (MSL) device may be enabled as a production root of trust in Naza One.
It is intentionally stricter than a functional demonstration. It covers
metrology, enrollment, false-accept and false-reject performance, conditional
min-entropy, helper-data leakage, dynamic model-extraction resistance, physical
cloning, fault injection, lifecycle drift, protocol conformance, and release
evidence.

MSL is an experimental possession-bound physical primitive. The label
"post-quantum" applies only to the independently implemented ML-KEM component
of the hybrid key establishment. It does **not** imply that the optical
hardness assumption has a reduction to a post-quantum mathematical problem,
that the optical surface creates entropy through deterministic transforms, or
that this system has been independently certified.

No camera-only implementation, simulated surface, RGB transform, entropy
score, or quantum-inspired statevector is acceptable as possession evidence.
The production host must use the `MslSecureReader` boundary and must reject raw
measurements, debug firmware, unauthenticated enrollment data, stale counters,
and unverified reader attestations.

Normative terms **MUST**, **MUST NOT**, **SHOULD**, and **MAY** have their usual
requirements meaning. Candidate numerical thresholds in Section 5 are release
policy defaults, not physical facts. A profile may tighten them; weakening them
requires a written threat-model exception and new review.

## 2. Normative system model

### 2.1 State and measurement model

For challenge instruction (c_t), hidden material state (s_t), environment
(e_t), and measurement noise \(\eta_t\):

\[
c_t=(\lambda_t,I_t,\theta_t,P_t,\Delta_t,\phi_t),
\qquad C=(c_1,\ldots,c_n)
\]

\[
s_{t+1}=F_{\vartheta}(s_t,c_t,e_t),
\qquad m_t=G_{\vartheta}(s_t,c_t,e_t)+\eta_t
\]

The surface-specific parameter \(\vartheta\) is not assumed recoverable by the
legitimate reader. The security target is resistance to acceptance-oriented
prediction of a fresh trajectory after bounded adaptive observations.

For detector channel (j), the calibrated radiometric model is:

\[
y_j(t)=\int I(\lambda,t)R(\lambda;s_t,c_t)
D_j(\lambda)H_j(\lambda,\theta_t,P_t)\,d\lambda+\eta_j(t).
\]

The calibration transform MUST be versioned:

\[
\widehat m_t=\mathcal C_v(r_t,d_t,g_t,T_t,\lambda_t),
\]

where (r_t) is raw ADC output, (d_t) dark response, (g_t) gain/reference
state, and (T_t) measured temperature. Residual calibration error MUST be
carried into the reliability budget rather than removed from reports.

### 2.2 Digital path

The normative path is:

\[
C\rightarrow M\rightarrow z=T_v(M,e)\rightarrow f=Q_v(z)
\rightarrow w=\operatorname{Quantize}_{v}(f)
\rightarrow K_{\rm surface}=\operatorname{Rep}(w,P).
\]

Here, (P) is authenticated public helper data. (T_v), (Q_v), the
quantizer, reliability mask, and secure-sketch code are deterministic and add
no entropy. The host combines the reconstructed secret with an authenticated
ML-KEM shared secret:

\[
\begin{aligned}
\tau &= H(\textsf{version}\|\textsf{device}\|\textsf{profile}\|
\textsf{purpose}\|N_V\|N_D\|ctr\|H(C)\|H(FW)),\\
PRK &= \operatorname{HMAC}_{H(\textsf{domain}\|\tau)}
(K_{\rm surface}\|K_{\rm ML-KEM}),\\
K_{\rm session} &= \operatorname{Expand}(PRK,
\textsf{device}\|\textsf{profile}\|\textsf{purpose}\|\tau,32).
\end{aligned}
\]

The implementation MUST use an approved, independently tested ML-KEM
implementation consistent with [FIPS 203](https://csrc.nist.gov/pubs/fips/203/final),
including applicable published errata. Hybrid extraction and expansion SHOULD
follow the two-step principles in
[NIST SP 800-56C Rev. 2](https://csrc.nist.gov/pubs/sp/800/56/c/r2/final).

### 2.3 Acceptance event

An optical trial is accepted only if every predicate is true:

\[
A = A_{reset}\land A_{dose}\land A_{timing}\land A_{sensor}
\land A_{decode}\land A_{attest}\land A_{fresh}\land A_{counter}
\land A_{transcript}.
\]

Reported FAR and FRR MUST use this end-to-end event. Component-only decoder
results may be reported separately but MUST NOT be labeled system FAR or FRR.

## 3. Roles, independence, and preregistration

The following roles MUST be identifiable in the evidence package:

1. Surface fabrication and packaging owner.
2. Reader hardware and calibration owner.
3. Firmware and host-protocol owner.
4. Enrollment authority and key custodian.
5. Statistical analysis owner.
6. Independent red-team owner.
7. Release authority.

The final holdout evaluator MUST NOT tune transforms, thresholds, masks,
decoder parameters, environmental compensation, or attack hyperparameters on
the holdout set. Before unblinding, the team MUST freeze and hash:

- hypotheses and primary endpoints;
- device and session inclusion/exclusion rules;
- profile definition and optical safety limits;
- train/development/holdout split assignment;
- feature transform, quantizer, code, and helper-data format;
- statistical estimators and confidence level;
- attack families, query budgets, and compute budgets;
- pass/fail thresholds and multiple-testing correction;
- software, firmware, calibration, and analysis container identities.

Exploratory findings are permitted but MUST be labeled exploratory and
confirmed on a new untouched dataset.

## 4. Device population and experimental unit

### 4.1 Required hierarchy

Data MUST preserve this hierarchy:

\[
\text{lot}\supset\text{wafer/batch}\supset\text{surface}
\supset\text{reader}\supset\text{session}\supset\text{reset}
\supset\text{challenge}\supset\text{measurement}.
\]

Repeated measurements of one challenge on one surface are not independent
device trials. Confidence calculations MUST use the appropriate cluster as the
experimental unit or use a hierarchical model/cluster bootstrap that preserves
the dependence structure.

### 4.2 Minimum characterization population

Before production-standard qualification, use at least:

- 3 independent fabrication lots;
- 100 surfaces total and at least 25 per represented lot;
- 10 readers across at least 2 hardware builds;
- 5 non-consecutive enrollment sessions per surface spanning at least 14 days;
- 3 independent mechanical reseats per applicable session;
- 10 verified resets per surface/environment corner;
- separate development and locked holdout surfaces, with no surface appearing
  in more than one split.

High-assurance qualification SHOULD use at least 300 surfaces, 5 lots, 20
readers, and 90 days of longitudinal evidence. If manufacturing variation is
larger than anticipated, a prospective power analysis MUST increase these
numbers.

### 4.3 Split policy

Split by physical surface and fabrication lot, never by measurement row.
A recommended baseline is 50% training/enrollment research, 20% development,
and 30% blinded holdout, while reserving at least one complete lot for
out-of-lot generalization testing.

## 5. Qualification profiles and release gates

The following are candidate minimum gates. Every bound is one-sided 95%
unless a profile states 99%. Passing one row does not waive any other gate.

| Gate | Research P0 | Production P1 | High-assurance P2 |
|---|---:|---:|---:|
| Legitimate FRR upper bound | 5% | 1% | 0.5% |
| Random-impostor FAR upper bound | \(10^{-4}\) | \(10^{-6}\) | \(10^{-7}\) |
| DORR adversarial accept upper bound | \(10^{-3}\) at \(q=10^4\) | \(10^{-5}\) at \(q=10^5\) | \(10^{-6}\) at \(q=10^6\) |
| Post-decoder key disagreement upper bound | \(10^{-5}\) | \(10^{-7}\) | \(10^{-9}\) |
| Conditional entropy security margin | 32 bits | 64 bits | 96 bits |
| Attestation/replay/counter false acceptance | 0 observed | 0 observed | 0 observed |
| Raw-response production API exposure | prohibited | prohibited | prohibited |

For zero observed false accepts in (N) independent Bernoulli trials, the
exact one-sided Clopper-Pearson upper bound is:

\[
p_U=1-\alpha^{1/N}\approx\frac{-\ln\alpha}{N}.
\]

At \(\alpha=0.05\), zero failures require approximately:

- 29,956 trials to support (p<10^{-4});
- 299,572 trials to support (p<10^{-5});
- 2,995,731 trials to support (p<10^{-6});
- 29,957,321 trials to support (p<10^{-7}).

If trial independence is not defensible, these counts are insufficient. Use
cluster-aware bounds, effective sample size, or conservative per-device
aggregation. Extrapolated tail models MUST be reported separately and may not
replace direct evidence unless release policy explicitly approves the model.

## 6. Calibration and measurement-system analysis

### 6.1 Calibration chain

Each reader MUST have traceable records for:

- wavelength accuracy and repeatability;
- source spectral power, pulse linearity, and settling time;
- detector dark current, read noise, gain, nonlinearity, saturation, and
  channel cross-talk;
- angle, polarization, phase/modulation, focus, and position accuracy;
- trigger latency, jitter, pulse duration, and detector aperture timing;
- temperature, humidity, and optical-dose sensors;
- reference target history and calibration expiration;
- firmware, FPGA, MCU, and calibration-table hashes.

For each calibrated quantity (x), report bias (b=\bar{x}-x_{ref}),
repeatability standard deviation (s_r), reproducibility standard deviation
(s_R), expanded uncertainty (U=k u_c), and the coverage factor (k).

### 6.2 Gauge repeatability and reproducibility

Fit a crossed random-effects model where feasible:

\[
y_{ijkl}=\mu+D_i+R_j+O_k+(DR)_{ij}+\epsilon_{ijkl},
\]

with device (D), reader (R), operator/setup (O), interaction, and repeat
error. Report variance components and:

\[
\%GRR=100\frac{\sqrt{\sigma_R^2+\sigma_O^2+
\sigma_{DR}^2+\sigma_\epsilon^2}}{\sigma_{total}}.
\]

GRR MUST be evaluated in raw calibrated space and in acceptance-feature space.
A low aggregate GRR does not excuse a single unstable key-bearing coordinate.

### 6.3 Mandatory fault flags

The reader MUST fail closed on saturation, underexposure, calibration expiry,
reference drift, timing error, missing sensor samples, unsupported profile,
optical-dose excess, reset failure, malformed challenge, attestation failure,
or firmware measurement mismatch. Fault thresholds MUST be validated by
deliberately crossing both sides of each boundary.

## 7. Enrollment and dataset protocol

### 7.1 Enrollment sequence

For every surface:

1. Verify package identity, tamper state, reader identity, firmware
   measurement, and calibration validity.
2. Execute the profile-defined reset and record convergence evidence.
3. Acquire dark/reference controls and reject invalid sensor conditions.
4. Execute randomized challenge blocks with control probes interleaved.
5. Repeat across sessions, readers, reseats, and environmental corners.
6. Compute transforms using training data only.
7. Estimate per-feature legitimate and between-device distributions.
8. Select reliability masks and guard bands on development data only.
9. Generate helper data with a versioned secure-sketch implementation.
10. Authenticate the enrollment record and move the device to production lock.
11. Evaluate once on blinded holdout data; do not retune after unblinding.

### 7.2 Reliability score

For feature (j), use a robust enrollment center and scale where distributions
are non-Gaussian:

\[
\widetilde\mu_j=\operatorname{median}(z_j),\qquad
\widetilde\sigma_j=1.4826\operatorname{median}|z_j-\widetilde\mu_j|.
\]

For threshold \(\tau_j\), define normalized margin:

\[
r_j=\frac{|\widetilde\mu_j-\tau_j|}
{\widetilde\sigma_j+\epsilon}.
\]

Feature selection MUST jointly constrain within-device stability,
between-device separability, estimated conditional entropy, helper leakage,
environment sensitivity, and surrogate-model predictability. Selecting only
on reliability is prohibited.

### 7.3 Enrollment record

The authenticated record MUST include:

- device, surface, reader-family, and profile identifiers;
- profile epoch and complete profile hash;
- firmware and calibration measurements;
- transform, mixer, quantizer, reliability-mask, and code identifiers;
- helper data and an explicit leakage bound;
- environmental envelope and lifecycle limits;
- enrollment authority, timestamp, counter, and revocation state;
- canonical encoding version and authenticated record digest.

Raw spectra MUST NOT be included in operational enrollment records. Laboratory
raw data MUST be encrypted under a separate research key, access logged,
retention bounded, and excluded from production telemetry.

## 8. FAR, FRR, ROC, and decoder reliability

### 8.1 Definitions

Let (A(x,d,C,e)) be the end-to-end acceptance decision for observation (x)
claimed as device (d):

\[
\operatorname{FAR}=P[A=1\mid d_{source}\ne d_{claim}],
\qquad
\operatorname{FRR}=P[A=0\mid d_{source}=d_{claim}].
\]

Report at least:

- random-impostor FAR;
- nearest-neighbor/device-similarity FAR;
- cross-lot and same-lot FAR;
- cross-reader and same-reader FAR;
- physical-clone FAR;
- injection/replay FAR;
- DORR model FAR at each query budget;
- FRR by environment, reader, lot, age, reseat, and reset history;
- pre-decoder BER/erasure rate and post-decoder key disagreement rate.

For (n) bits and reconstructed word (w'):

\[
BER=\frac{1}{n}\sum_{i=1}^{n}\mathbf 1[w_i\ne w'_i],
\quad
ER=\frac{1}{n}\sum_{i=1}^{n}\mathbf 1[w'_i=\bot].
\]

### 8.2 Confidence intervals

Use exact binomial intervals for sparse events and Wilson intervals for routine
FRR summaries. For clustered trials, use a cluster bootstrap resampling the
highest independent unit (normally surface) or a preregistered generalized
linear mixed model. Report point estimate, bound, numerator, denominator, and
number of independent surfaces; never report only a percentage.

If (X\sim\operatorname{Binomial}(N,p)), the two-sided Clopper-Pearson interval
is defined using beta quantiles:

\[
p_L=B^{-1}(\alpha/2;X,N-X+1),\quad
p_U=B^{-1}(1-\alpha/2;X+1,N-X).
\]

### 8.3 Threshold selection

Plot ROC and DET curves on development data, but qualify only the frozen
operating point on holdout data. Equal-error rate is descriptive and MUST NOT
be used as the production gate. Thresholds MUST NOT be changed per trial,
attacker class, or environmental result after identity is known.

## 9. Entropy and helper-data leakage

### 9.1 Entropy claim

The security quantity is conditional min-entropy against attacker information
(E), not Shannon entropy of mixer probabilities:

\[
H_\infty(W\mid E)=-\log_2
\mathbb E_{e\leftarrow E}\left[\max_w P(W=w\mid E=e)\right].
\]

The entropy assessment MUST include manufacturing lot, public profile,
challenge policy, environmental telemetry, calibration information, helper
data, reliability mask, observed transcripts, and attack-model outputs in
(E). Follow the source-model, data-collection, restart-test, health-test, and
conservative-estimation principles of
[NIST SP 800-90B](https://csrc.nist.gov/pubs/sp/800/90/b/final), while clearly
stating that MSL authentication measurements are not automatically an approved
random-bit-generator entropy source.

### 9.2 Leakage budget

The final key length ℓ MUST satisfy:

\[
\ell \le H_\infty(W\mid E)-L_{helper}-L_{mask}-L_{meta}
-L_{model}-2\log_2(1/\epsilon_{ext})-M_{sec}.
\]

For a binary linear syndrome helper (P=HW^T), a conservative structural
bound is:

\[
L_{helper}\le \operatorname{rank}_{GF(2)}(H),
\]

augmented by leakage from code choice, erasure positions, reliability values,
feature masks, retries, decoder timing, and update history. Do not count
deterministic SHA, KDF, lattice, or statevector output as additional entropy.

### 9.3 Required estimators and stress tests

At minimum:

- collision, most-common-value, Markov/dependency, and compression/predictor
  analyses appropriate to IID/non-IID data;
- per-lot, per-reader, and pooled estimates, using the worst defensible bound;
- restart/reset analysis;
- entropy estimate after every public-data disclosure;
- learned predictors trained to minimize conditional surprise;
- sensitivity to feature selection and discretization;
- bootstrap uncertainty and a preregistered conservative final bound.

## 10. DORR and model-extraction red team

### 10.1 Security experiment

For query budget (q), attacker (\mathcal A), fresh challenge (C^*), and
acceptance predicate (A):

\[
\operatorname{Adv}^{DORR}_{\mathcal A}(q)=
P\left[A(\widehat M^*,C^*)=1:
\widehat M^*\leftarrow\mathcal A(\{(C_i,M_i)\}_{i=1}^{q},C^*)\right].
\]

The primary loss is end-to-end acceptance, or a validated differentiable
surrogate for it—not average spectral MSE. Report attack acceptance versus
(q\) on logarithmic query budgets, including confidence bounds.

### 10.2 Required attack families

The red team MUST evaluate:

- constant, mean, nearest-neighbor, interpolation, and replay baselines;
- linear/ridge/logistic models and kernel methods;
- Gaussian processes where tractable;
- random forests and gradient-boosted trees;
- recurrent networks, temporal convolution, transformers, and modern
  state-space sequence models;
- latent nonlinear system identification and neural ODE/state-transition
  models;
- active learning, Bayesian optimization, and acceptance-guided query choice;
- transfer learning across devices, readers, and fabrication lots;
- membership/linkability attacks against helper data and telemetry;
- white-box attacks using transform, quantizer, decoder, and profile details;
- side-information attacks using temperature, timing, optical power,
  polarization, and high-resolution spectroscopy;
- model ensembles and uncertainty-calibrated abstention.

Attack compute, wall time, accelerator type, hyperparameter budget, random
seeds, and early-stopping rules MUST be equalized or justified. The strongest
validated attack determines the DORR result. Security MUST NOT be claimed from
failure of one model class.

### 10.3 Adaptive-query controls

Evaluate both unconstrained laboratory access and production-limited access.
Rate limiting is defense in depth and MUST NOT be credited as intrinsic surface
entropy. Record query count, cumulative optical dose, reset count, challenge
coverage, and material aging during attack acquisition.

## 11. Environmental, mechanical, and lifecycle matrix

At minimum, characterize the full factorial core below, then add application
specific corners. Randomize run order and include center-point repeats.

| Factor | Required levels |
|---|---|
| Temperature | profile minimum, nominal, profile maximum; 5-degree sweeps near failure boundaries |
| Relative humidity | 20%, 50%, 80%, plus condensation-risk assessment |
| Source power | -10%, nominal, +10%, and fault boundary |
| Wavelength | commanded bins plus calibration-error offsets |
| Incidence angle | every profile bin plus tolerance offsets |
| Polarization | every profile state plus extinction/rotation error |
| Pulse timing | nominal, jitter distribution, and both fault boundaries |
| Mechanical placement | reseat, translation, rotation, focus, vibration |
| Supply | minimum, nominal, maximum, brownout and recovery |
| EMI/EMC | conducted/radiated stress appropriate to deployment |
| Optical contamination | dust, fingerprints, cleaning cycles, controlled films |
| Aging | 0%, 10%, 25%, 50%, 75%, 100%, and 120% rated challenge life |
| Storage | cold, hot, humid, UV exposure, transport shock |

For drift coordinate (j), fit both parametric and nonparametric trends:

\[
z_{j,t}=\beta_{0j}+\beta_{1j}t+\beta_{2j}T_t+
\beta_{3j}RH_t+b_{device}+b_{reader}+\epsilon_{j,t}.
\]

Report residual structure and change points. Compensation models MUST be frozen
and attacked as public algorithms. Re-enrollment thresholds MUST be set before
the lifecycle holdout is analyzed.

## 12. Reset, statefulness, and desynchronization

### 12.1 Reset convergence

Let (P_0) be the enrolled reset-state distribution and (P_k) the state after
reset attempt (k). Define a preregistered distribution distance (D), such as
energy distance or maximum mean discrepancy:

\[
D(P_k,P_0)\le\tau_{reset}.
\]

Qualification MUST test reset after nominal completion, aborted pulses,
brownout, over-temperature, malformed instructions, communication loss, and
maximum-dose execution. A failed reset MUST enter FAULT and MUST NOT continue
from an uncertain state.

### 12.2 Path dependence

For prefixes (C_a\ne C_b) ending in common probe (c^*), measure:

\[
\Delta_{path}=d(m(c^*\mid C_a),m(c^*\mid C_b)).
\]

Path dependence passes only when between-prefix separation exceeds legitimate
repeat noise with a preregistered effect size and survives holdout evaluation.
The same experiment MUST estimate how quickly an attacker can infer hidden
state from a prefix.

### 12.3 Fault campaign

Inject skipped, duplicated, reordered, delayed, shortened, overpowered, and
wrong-polarization instructions. Every deviation outside tolerance MUST be
detected before key use, reflected in attested health, and followed by verified
reset. Test integer boundaries, unit confusion, endianness, truncated frames,
duplicate sequence numbers, and profile-version mismatch.

## 13. Physical clone, substitution, and sensor-injection testing

The physical red team MUST include:

- same-process and deliberately matched surfaces;
- high-resolution spectroscopy/tomography-derived replicas;
- printed, coated, deposited, multilayer, and replay-emitter approximations;
- surface removal, rotation, translation, replacement, and package bypass;
- detector electrical injection and ADC/DMA substitution;
- source-monitor spoofing and reference-channel manipulation;
- temperature/humidity sensor spoofing;
- optical replay with programmable emitters;
- firmware downgrade, debug unlock, faulted secure boot, and attestation-key
  substitution;
- bus probing, timing/power/EM leakage, glitching, and brownout;
- compromised host attempts to request raw trajectories or unrestricted
  adaptive challenges.

The production reader MUST attest the exact executed program, firmware
measurement, health summary, device/profile identity, and monotonic state.
Self-reported `productionFirmware=true` without cryptographic verification is
not evidence.

## 14. Protocol and cryptographic conformance

### 14.1 Canonical encoding

Generate cross-language test vectors for every field and reject:

- noncanonical lengths, duplicate fields, trailing data, ambiguous Unicode,
  signed/unsigned confusion, integer overflow, NaN/infinity, unsupported units,
  and alternate encodings of the same semantic value;
- challenge counts, arrays, identifiers, timestamps, and messages outside
  their explicit bounds;
- unknown protocol, profile, transform, helper, KDF, KEM, or firmware versions.

### 14.2 Freshness and rollback

Test verifier nonce reuse, device nonce repetition, expired/future requests,
counter rollback, counter jumps, concurrent sessions, interrupted counter
commit, database snapshot restore, enrollment-record rollback, helper-data
substitution, and profile-epoch downgrade. No key handle may be released before
the monotonic counter transition is durably committed and verified.

### 14.3 Key separation and destruction

Changing any of device ID, profile ID, purpose, nonce, counter, challenge,
firmware measurement, ML-KEM contribution, or protocol version MUST change the
session key and proof. Tests MUST cover all-zero, repeated, short, oversized,
and malformed ML-KEM contributions.

The reader MUST erase raw trajectories, lattice vectors, words, reconstructed
surface secrets, decoder work buffers, and temporary keys after success or
failure. The Dart host performs best-effort zeroization only; production keys
SHOULD remain in native secure hardware and be exposed as non-exportable
handles.

### 14.4 Attestation verification

Attestation tests MUST include invalid signature, wrong root, revoked device,
wrong device/profile, altered health, altered program digest, altered firmware
measurement, expired certificate, algorithm confusion, malformed certificate,
debug firmware, downgrade, and cloned attestation identity. Trust anchors and
revocation state MUST be authenticated and updateable through a separately
authorized path.

## 15. Manufacturing, enrollment authority, and data governance

Manufacturing and production security domains MUST be separated. Raw export is
permitted only in an explicitly identified laboratory firmware profile.
Production firmware MUST omit or cryptographically disable those commands.

Enrollment signing keys MUST be held separately from optical workstations and
SHOULD use an HSM or equivalent hardware-backed service. Use dual control for
profile signing, trust-anchor rotation, mass revocation, and production unlock.
Every surface-reader substitution attempt during provisioning MUST be logged
and tested.

Laboratory datasets are security-sensitive. The data-management plan MUST
specify classification, encryption, key custody, access roles, immutable audit
logging, retention, deletion limitations, backup, incident response, export
controls, and whether any sample metadata is personally identifying.

Production telemetry is restricted to bounded health categories, calibration
age, reset/fault counts, optical dose bucket, firmware/profile version, and
coarse reconstruction status. It MUST NOT contain spectra, lattice coordinates,
quantized words, masks, helper internals, secret-dependent timing, or stable
cross-service fingerprints.

## 16. Statistical analysis plan

The signed analysis plan MUST identify one primary reliability endpoint and one
primary adversarial endpoint per profile. Secondary endpoints require false
discovery rate or family-wise error control where inferential claims are made.

Use mixed-effects logistic regression for factor analysis where appropriate:

\[
\operatorname{logit}P(A_{ijk}=1)=\beta_0+\beta^T x_{ijk}
+u_{device_i}+v_{reader_j}+w_{lot_k}.
\]

Report fixed effects, variance components, calibration plots, residual checks,
and sensitivity to link/model choice. Rare-event separation may require exact
or penalized methods. A model-derived FAR tail MUST be checked against direct
observations and reported as extrapolation.

Before acquisition, compute sample size for reliability comparisons. For two
proportions (p_0,p_1), an approximate equal-group requirement is:

\[
n\approx\frac{\left[z_{1-\alpha/2}\sqrt{2\bar p(1-\bar p)}+
z_{1-\beta}\sqrt{p_0(1-p_0)+p_1(1-p_1)}\right]^2}
{(p_1-p_0)^2},\quad \bar p=(p_0+p_1)/2,
\]

then inflate for clustering by the design effect:

\[
DE=1+(m-1)\rho,\qquad n_{clustered}=n\,DE.
\]

The report MUST disclose missingness, excluded trials, aborted sessions,
outliers, protocol deviations, and all analyses performed after unblinding.
Aborted trials count as rejects for end-to-end FRR unless a preregistered,
externally observable exclusion rule applies equally in deployment.

## 17. Data and evidence format

Each immutable trial record MUST contain or reference:

```text
study_id, preregistration_hash, trial_id
lot_id, surface_id_pseudonym, reader_id, hardware_revision
firmware_measurement, calibration_id, profile_id, profile_hash
session_id, reset_id, challenge_seed_commitment, challenge_digest
environmental_setpoints, environmental_measurements
timing_error_max, saturation_flag, underexposure_flag, dose_total
attestation_result, counter_before, counter_after
decoder_status, correction_count, erasure_count, confidence_bucket
accept_or_reject, failure_class
attack_family, attack_version, query_budget, compute_budget
timestamp_utc, software_container_digest, analyst_blind_code
record_digest, record_signature
```

Operational exports MUST omit raw response and secret-bearing fields. Research
datasets MAY store them only in a separately encrypted, access-controlled
artifact linked by a content digest.

Every result table MUST state population, independent-unit count, total trial
count, failures, estimate, interval method, confidence level, split, profile,
firmware, calibration revision, and whether the result was preregistered.

## 18. Stage gates and stop conditions

### Gate 0: Metrology readiness

Pass only if calibration uncertainty, timing control, detector range, and GRR
meet preregistered limits. Stop if the measurement system cannot distinguish
surface variation from reader noise.

### Gate 1: Reset and state dynamics

Pass only if reset convergence, repeatability, path dependence, dose safety,
and abort recovery pass across corners. Stop before feature optimization if
reset-state variance is uncontrolled.

### Gate 2: Uniqueness and reliability

Pass only if frozen transforms and masks meet FRR, BER/erasure, inter-device
separation, and cross-reader/lot requirements on holdout data.

### Gate 3: Entropy and helper data

Pass only if conservative conditional min-entropy minus all leakage and margins
supports the selected key length. Stop if security depends on hidden transform
weights or uncounted helper leakage.

### Gate 4: Adversarial resistance

Pass only if the strongest DORR, clone, replay, injection, side-channel, and
fault attacks remain below their confidence-bound gates. Stop if a modest-query
model reaches the acceptance target.

### Gate 5: Protocol and lifecycle

Pass only if canonical encoding, attestation, monotonic storage, key separation,
rotation, revocation, re-enrollment, reader replacement, aging, and recovery
tests pass.

### Gate 6: Independent release review

Release requires signed approval of the frozen profile, threat model, complete
evidence manifest, unresolved-anomaly register, residual-risk statement, and
production monitoring/rollback plan. No single aggregate score can override a
failed mandatory gate.

## 19. Required deliverables

The laboratory evidence package MUST include:

1. Signed protocol, profile, firmware, and hardware specifications.
2. Calibration procedures, certificates, uncertainty budgets, and GRR report.
3. Enrollment plan and authenticated-record schema.
4. Preregistration and cryptographic hashes of frozen analysis artifacts.
5. De-identified trial manifest and protected raw-data manifest.
6. FAR/FRR/BER/erasure/key-disagreement report with cluster-aware intervals.
7. Conditional min-entropy and helper-leakage report.
8. DORR/model-extraction report with code, seeds, budgets, and learning curves.
9. Physical clone, sensor injection, side-channel, and fault-injection report.
10. Environmental, mechanical, reset, aging, and service-life report.
11. Protocol conformance and cross-language test vectors.
12. Attestation PKI, revocation, secure-boot, and downgrade test report.
13. Manufacturing security, key custody, and production-lock audit.
14. Data-governance, privacy, telemetry, and incident-response plan.
15. Independent review findings, dispositions, and residual-risk acceptance.

## 20. Repository implementation mapping

| Requirement | Current repository surface | Status |
|---|---|---|
| Bounded/versioned challenge profile | `lib/security/metameric_surface_lattice.dart` | Implemented host contract |
| Canonical challenge encoding | `MslChallengeProgram.canonicalBytes` | Implemented |
| Fresh nonces and replay rejection | `MslProtocolEngine.authenticate` | Implemented in-process; remote verifier still required |
| Optical dose and request-rate limits | `MslProfile`, `MslProtocolEngine` | Implemented host gate |
| Reader health fail-closed checks | `MslReaderHealth` | Implemented contract; hardware evidence pending |
| Reader attestation | `MslReaderAttestationVerifier` | Contract implemented; native verifier/PKI pending |
| Monotonic encrypted counter | `metameric_surface_lattice_store.dart` | Implemented using Naza secure database |
| Hybrid secret extraction | `MslProtocolEngine` | Host combiner implemented; authenticated ML-KEM handshake integration pending |
| Opaque expiring key handles | `MslKeyHandle` | Implemented in process; native non-exportable handles preferred |
| Raw-response isolation | `MslSecureReader` boundary | Required by contract; native adapter pending |
| Fuzzy extractor/helper data | Native secure reader | Pending measured-data selection and validation |
| Physical reader and surface | External hardware | Pending |
| Laboratory evidence in this specification | `docs/msl-pq-laboratory-validation-spec.md` | Defined; execution pending |

## 21. References

- NIST, [FIPS 203: Module-Lattice-Based Key-Encapsulation Mechanism
  Standard](https://csrc.nist.gov/pubs/fips/203/final), including published
  errata.
- NIST, [SP 800-56C Rev. 2: Recommendation for Key-Derivation Methods in
  Key-Establishment Schemes](https://csrc.nist.gov/pubs/sp/800/56/c/r2/final).
- NIST, [SP 800-90B: Recommendation for the Entropy Sources Used for Random Bit
  Generation](https://csrc.nist.gov/pubs/sp/800/90/b/final), including the
  planning note and errata.
- `metameric_surface_lattice_pq_monograph_volume1 (2).docx`, MSL-PQ System
  Specification Revision 1.0, supplied design source.
- `SECURITY.md`, Naza One application security model.
- `docs/security-change-playbook.md`, repository security-change requirements.

## Appendix A: Qualification checklist

- [ ] Claim language distinguishes physical DORR evidence from ML-KEM security.
- [ ] Profile, analysis, splits, attacks, and gates were frozen before holdout.
- [ ] Population spans required lots, surfaces, readers, sessions, and time.
- [ ] Measurement uncertainty and GRR are below preregistered limits.
- [ ] Reset convergence and all abort-recovery paths pass.
- [ ] FAR/FRR bounds use independent or cluster-aware trial accounting.
- [ ] Rare-event claims have adequate direct trial counts.
- [ ] Conditional min-entropy subtracts helper, mask, metadata, and model leakage.
- [ ] Deterministic transforms receive zero entropy credit.
- [ ] Strongest acceptance-oriented DORR attack passes the query-budget gate.
- [ ] Clone, replay, injection, side-channel, and fault campaigns pass.
- [ ] Environmental corners and lifecycle holdout pass without retuning.
- [ ] Production firmware exposes no raw measurement command.
- [ ] Attestation covers execution, firmware, health, identity, and profile.
- [ ] Counter commit is durable before any key handle is released.
- [ ] ML-KEM implementation and hybrid transcript binding are independently tested.
- [ ] Enrollment authority, trust anchors, and revocation are separately protected.
- [ ] Evidence package is reproducible from signed manifests and archived code.
- [ ] Independent reviewers approved residual risk and production monitoring.

## Appendix B: Release decision record template

```text
Profile / epoch:
Hardware revisions:
Firmware measurement(s):
Calibration revision(s):
Enrollment-record format:
Helper-data scheme and leakage bound:
Holdout population and dates:
Legitimate trials / rejects / FRR upper bound:
Random-impostor trials / accepts / FAR upper bound:
Strongest DORR attack / q / trials / accepts / upper bound:
Clone and injection outcomes:
Conditional min-entropy lower bound:
Final key length and security margin:
Lifecycle evidence duration / challenge cycles:
Open anomalies and severity:
Threat-model exceptions:
Independent reviewer:
Release authority:
Decision: REJECT / RESEARCH ONLY / LIMITED PILOT / PRODUCTION
Signed evidence-manifest digest:
Decision timestamp (UTC):
```
