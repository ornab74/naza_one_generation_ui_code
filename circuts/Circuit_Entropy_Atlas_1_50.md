# Page Circuit & Entropy Atlas — Pages 1–50

Each page uses a deterministic NumPy 3-qubit state-vector circuit with rotation and entangling gates. Entropy is reported as the mean single-qubit von Neumann entropy in bits; the range is obtained by sweeping the page-local parameter interval. Measurement Shannon entropy is also included.

## Page 1
- Circuit depth: 3; topology id: 1
- R angle range: [4.163328, 4.495328] rad
- G angle range: [4.270553, 4.512913] rad
- B angle range: [1.980929, 2.117049] rad
- Mean entanglement entropy: 0.669252 bits
- Page entropy sweep range: [0.656223, 0.673984] bits
- Measurement Shannon entropy: 2.664470 bits
- Circuit sequence: `RX(R_theta*1.00+0.030, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.060, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.090, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.030, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+0.060, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RX(B_theta*1.07+0.090, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+0.030, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RX(G_theta*1.14+0.060, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+0.090, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))`
- Final statevector (real, imag): `[[0.08215028573141062,-0.2632583010222168],[-0.23495876989421938,0.11902553774380417],[0.3648432967549003,0.013172658798809658],[-0.05856022773887716,-0.017705606430678398],[-0.4466265501571738,-0.11718914342071438],[0.20309885246415343,0.3954788657535794],[0.1171642621778039,0.23572982196547002],[0.1732812151962673,-0.45537140424779265]]`

## Page 2
- Circuit depth: 4; topology id: 2
- R angle range: [1.757365, 2.101365] rad
- G angle range: [0.382951, 0.634071] rad
- B angle range: [0.138167, 0.279207] rad
- Mean entanglement entropy: 0.837931 bits
- Page entropy sweep range: [0.798035, 0.924212] bits
- Measurement Shannon entropy: 2.350784 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+0.060, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.120, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.180, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.060, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RX(G_theta*1.07+0.120, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+0.180, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+0.060, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RY(G_theta*1.14+0.120, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+0.180, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+0.060, wire=0) -> RZ(R_phi*0.85+0.114, wire=0) -> RY(G_theta*1.21+0.120, wire=1) -> RZ(G_phi*0.85+0.114, wire=1) -> RX(B_theta*1.21+0.180, wire=2) -> RZ(B_phi*0.85+0.114, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[-0.11796987439331745,0.06437615210625526],[-0.11018222912560635,0.18553771549845324],[0.362397282149876,-0.4335387246864643],[-0.09225808131820962,0.25727753602582487],[0.21539581311461348,0.05002512955479995],[-0.12091099286603595,-0.026176457314541074],[0.1273367334430691,0.35584685632303337],[0.2990675581878218,0.49487167433254003]]`

## Page 3
- Circuit depth: 2; topology id: 3
- R angle range: [5.634587, 5.990587] rad
- G angle range: [2.778534, 3.038414] rad
- B angle range: [4.578590, 4.724550] rad
- Mean entanglement entropy: 0.660912 bits
- Page entropy sweep range: [0.649682, 0.663149] bits
- Measurement Shannon entropy: 1.195072 bits
- Circuit sequence: `RY(R_theta*1.00+0.090, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.180, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.270, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+0.090, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+0.180, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+0.270, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[-0.204132289301218,-0.5196575246032342],[-0.05556185306886879,-0.05518030127519474],[-0.05436448498044179,0.004272913514858527],[0.37636839886267415,-0.7097247990101252],[-0.0886651118592839,0.012698034761078371],[0.008202014195222075,-0.004525295132404912],[-0.0026082736235056077,0.004077270117407577],[0.1555354064972865,0.03863521755105217]]`

## Page 4
- Circuit depth: 3; topology id: 0
- R angle range: [3.228624, 3.596624] rad
- G angle range: [5.174117, 5.442757] rad
- B angle range: [2.735828, 2.886708] rad
- Mean entanglement entropy: 0.370704 bits
- Page entropy sweep range: [0.339020, 0.464061] bits
- Measurement Shannon entropy: 0.856935 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+0.120, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.240, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.360, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.120, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+0.240, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RX(B_theta*1.07+0.360, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+0.120, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RX(G_theta*1.14+0.240, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+0.360, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))`
- Final statevector (real, imag): `[[0.04924110771597186,-0.03135766596992204],[-0.06333881823280778,-0.17345127249724776],[-0.0879225117184581,0.07281873730752755],[0.008840814894040249,0.012245466078518792],[0.16450246179968203,0.9139212626847177],[-0.11815558168947021,0.017842382283159965],[0.04137755132395775,-0.06968674881325908],[0.1797831885630638,0.18371512249521701]]`

## Page 5
- Circuit depth: 4; topology id: 1
- R angle range: [0.822661, 1.202661] rad
- G angle range: [1.286515, 1.563915] rad
- B angle range: [0.893065, 1.048865] rad
- Mean entanglement entropy: 0.576989 bits
- Page entropy sweep range: [0.453101, 0.687946] bits
- Measurement Shannon entropy: 2.227749 bits
- Circuit sequence: `RY(R_theta*1.00+0.150, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.300, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.450, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.150, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RX(G_theta*1.07+0.300, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+0.450, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+0.150, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RY(G_theta*1.14+0.300, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+0.450, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+0.150, wire=0) -> RZ(R_phi*0.85+0.285, wire=0) -> RY(G_theta*1.21+0.300, wire=1) -> RZ(G_phi*0.85+0.285, wire=1) -> RX(B_theta*1.21+0.450, wire=2) -> RZ(B_phi*0.85+0.285, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[-0.2733494185453167,-0.04974369911491269],[-0.040886646975410695,0.1923445286588644],[0.16380124679706273,-0.11865809743365972],[0.2860961679892602,0.1115273711934313],[0.12852064834023885,-0.6808275679940757],[-0.024646638683942467,0.010288678188338845],[0.329115015441531,0.29504141393240585],[0.13062438082478656,0.23611788050279212]]`

## Page 6
- Circuit depth: 2; topology id: 2
- R angle range: [4.699883, 5.091883] rad
- G angle range: [3.682099, 3.968259] rad
- B angle range: [5.333488, 5.494208] rad
- Mean entanglement entropy: 0.498569 bits
- Page entropy sweep range: [0.321792, 0.649897] bits
- Measurement Shannon entropy: 1.915784 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+0.180, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.360, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.540, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+0.180, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+0.360, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+0.540, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[-0.5979263508892921,-0.014583207327650009],[0.05284578601238683,0.03856400195755954],[0.09534751608347222,-0.6209072168320461],[0.0015225171704476973,-0.018961978259287738],[-0.3222605999339648,-0.22775617740647303],[0.080991256555285,0.03675165885156087],[0.04531886038223628,0.2502180309061855],[-0.11754228164681435,0.0299777494077412]]`

## Page 7
- Circuit depth: 3; topology id: 3
- R angle range: [2.293919, 2.697919] rad
- G angle range: [6.077682, 6.372602] rad
- B angle range: [3.490726, 3.656366] rad
- Mean entanglement entropy: 0.387381 bits
- Page entropy sweep range: [0.241891, 0.676768] bits
- Measurement Shannon entropy: 2.172028 bits
- Circuit sequence: `RX(R_theta*1.00+0.210, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.420, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.630, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.210, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+0.420, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RX(B_theta*1.07+0.630, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+0.210, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RX(G_theta*1.14+0.420, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+0.630, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))`
- Final statevector (real, imag): `[[0.06403202442498433,-0.10665763296246461],[-0.1416880337076123,0.0917638754997921],[0.05542834547326545,-0.1396629923378611],[-0.03179706772684073,0.0760194501336228],[-0.09013467198529304,0.29785965193703545],[0.5121258106654039,0.002112978243822783],[-0.3774693823500353,0.04013165657665274],[-0.3551523084357684,0.5452624043335795]]`

## Page 8
- Circuit depth: 4; topology id: 0
- R angle range: [-0.112044, 0.303956] rad
- G angle range: [2.190080, 2.493760] rad
- B angle range: [1.647963, 1.818523] rad
- Mean entanglement entropy: 0.315411 bits
- Page entropy sweep range: [0.073246, 0.538718] bits
- Measurement Shannon entropy: 1.765400 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+0.240, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.480, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.720, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.240, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RX(G_theta*1.07+0.480, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+0.720, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+0.240, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RY(G_theta*1.14+0.480, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+0.720, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+0.240, wire=0) -> RZ(R_phi*0.85+0.057, wire=0) -> RY(G_theta*1.21+0.480, wire=1) -> RZ(G_phi*0.85+0.057, wire=1) -> RX(B_theta*1.21+0.720, wire=2) -> RZ(B_phi*0.85+0.057, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[0.5018557186937446,0.10246337337700087],[0.7536428259969581,0.011705078805993531],[-0.15625148960975602,0.10395626627014351],[-0.09021986972532779,0.07865573361918807],[-0.07599353006921979,-0.1909742970110439],[-0.09436616731938127,-0.005233796919205371],[0.04273129959932109,0.03622982050150976],[0.2559592423500481,-0.012146256959093191]]`

## Page 9
- Circuit depth: 2; topology id: 1
- R angle range: [3.765178, 4.193178] rad
- G angle range: [4.585663, 4.898103] rad
- B angle range: [6.088386, 6.263866] rad
- Mean entanglement entropy: 0.806157 bits
- Page entropy sweep range: [0.759467, 0.849760] bits
- Measurement Shannon entropy: 2.198550 bits
- Circuit sequence: `RY(R_theta*1.00+0.270, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.540, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.810, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+0.270, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+0.540, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+0.810, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[0.6639563360862218,0.08360286765872682],[0.14238459477578183,-0.1994226719667441],[-0.1601344059736584,-0.009877605148079144],[-0.40578217703746206,-0.07657047764146604],[-0.0033829419947420426,0.06632430079085913],[-0.14006601661790494,-0.4402717631896599],[-0.1766123569619165,0.15579565990490168],[-0.1500570129710981,0.004191657780070822]]`

## Page 10
- Circuit depth: 3; topology id: 2
- R angle range: [1.359215, 1.799215] rad
- G angle range: [0.698061, 1.019261] rad
- B angle range: [4.245624, 4.426024] rad
- Mean entanglement entropy: 0.806404 bits
- Page entropy sweep range: [0.751572, 0.913926] bits
- Measurement Shannon entropy: 2.766895 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+0.300, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.600, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+0.900, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.300, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+0.600, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RX(B_theta*1.07+0.900, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+0.300, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RX(G_theta*1.14+0.600, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+0.900, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))`
- Final statevector (real, imag): `[[-0.0531885504356579,0.3886248665131007],[-0.49356569866705197,-0.1367062564121902],[0.09790589138427255,-0.3768731450982783],[0.39686694865872735,0.10508176866033474],[0.24346117873759898,0.2172812835116918],[0.14882667232088448,-0.23018553578323445],[0.11581881456729787,0.1339773830591038],[0.20357030848071533,-0.09621558715729148]]`

## Page 11
- Circuit depth: 4; topology id: 3
- R angle range: [5.302437, 5.622437] rad
- G angle range: [3.141824, 3.375424] rad
- B angle range: [2.429922, 2.561122] rad
- Mean entanglement entropy: 0.360158 bits
- Page entropy sweep range: [0.295450, 0.453970] bits
- Measurement Shannon entropy: 2.551097 bits
- Circuit sequence: `RY(R_theta*1.00+0.330, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.660, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+0.990, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.330, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RX(G_theta*1.07+0.660, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+0.990, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+0.330, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RY(G_theta*1.14+0.660, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+0.990, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+0.330, wire=0) -> RZ(R_phi*0.85+0.228, wire=0) -> RY(G_theta*1.21+0.660, wire=1) -> RZ(G_phi*0.85+0.228, wire=1) -> RX(B_theta*1.21+0.990, wire=2) -> RZ(B_phi*0.85+0.228, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[-0.41054586981303887,-0.04422082117765684],[0.198934674029486,-0.23756551361524675],[-0.44952669255497824,0.26043143624207743],[0.43173239006508957,-0.29002396945580483],[0.13485075423576687,-0.21869045909503562],[-0.12073828677716456,0.16135135191205657],[0.25032462965066604,-0.14387623092743582],[-0.03576071129746077,0.04260089421099058]]`

## Page 12
- Circuit depth: 2; topology id: 0
- R angle range: [2.896474, 3.228474] rad
- G angle range: [5.537407, 5.779767] rad
- B angle range: [0.587159, 0.723279] rad
- Mean entanglement entropy: 0.778101 bits
- Page entropy sweep range: [0.712153, 0.811578] bits
- Measurement Shannon entropy: 2.059049 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+0.360, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.720, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.080, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+0.360, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+0.720, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+1.080, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[-0.04094634877332802,-0.07933868280018014],[-0.20518307499571933,0.11331412170237565],[-0.11995064464794293,-0.05179655853334929],[-0.22006053789545577,-0.49579335556278925],[-0.043897067243928826,0.2983258599221025],[-0.22273679961084344,-0.6447154806563312],[-0.09629884111317134,0.20426395348974738],[-0.1216444245922032,-0.0615650344459234]]`

## Page 13
- Circuit depth: 3; topology id: 1
- R angle range: [0.490511, 0.834511] rad
- G angle range: [1.649805, 1.900925] rad
- B angle range: [5.027582, 5.168622] rad
- Mean entanglement entropy: 0.520271 bits
- Page entropy sweep range: [0.432627, 0.563786] bits
- Measurement Shannon entropy: 1.762901 bits
- Circuit sequence: `RX(R_theta*1.00+0.390, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.780, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.170, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.390, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+0.780, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RX(B_theta*1.07+1.170, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+0.390, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RX(G_theta*1.14+0.780, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+1.170, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))`
- Final statevector (real, imag): `[[-0.1453525284384602,0.1087052699708467],[0.12099711323951116,0.0038424012986504373],[-0.006103088040449083,-0.3886477486509108],[-0.018958405850959467,-0.2491406171072519],[0.18109273256982109,-0.11936006474336633],[-0.035436406136284876,-0.03376980283219376],[-0.12605065530848547,-0.7908990569903772],[0.16601043870920137,0.14310436651730796]]`

## Page 14
- Circuit depth: 4; topology id: 2
- R angle range: [4.367733, 4.723733] rad
- G angle range: [4.045388, 4.305268] rad
- B angle range: [3.184820, 3.330780] rad
- Mean entanglement entropy: 0.748197 bits
- Page entropy sweep range: [0.641922, 0.846833] bits
- Measurement Shannon entropy: 2.689258 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+0.420, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.840, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+1.260, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.420, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RX(G_theta*1.07+0.840, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+1.260, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+0.420, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RY(G_theta*1.14+0.840, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+1.260, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+0.420, wire=0) -> RZ(R_phi*0.85+0.000, wire=0) -> RY(G_theta*1.21+0.840, wire=1) -> RZ(G_phi*0.85+0.000, wire=1) -> RX(B_theta*1.21+1.260, wire=2) -> RZ(B_phi*0.85+0.000, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[0.2139807655064267,0.18619961773985824],[0.28305925265616017,-0.19913788240154076],[-0.09470670256322536,0.034207038661120494],[-0.041562469513699817,-0.4502923294959285],[0.24024308136228512,-0.009150209887587635],[0.42776405429073794,0.2938538721958605],[0.29703281518486235,-0.06531989959445113],[0.13976928736225902,0.3820603494806292]]`

## Page 15
- Circuit depth: 2; topology id: 3
- R angle range: [1.961770, 2.329770] rad
- G angle range: [0.157786, 0.426426] rad
- B angle range: [1.342057, 1.492937] rad
- Mean entanglement entropy: 0.497498 bits
- Page entropy sweep range: [0.327689, 0.648041] bits
- Measurement Shannon entropy: 1.128397 bits
- Circuit sequence: `RY(R_theta*1.00+0.450, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+0.900, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.350, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+0.450, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+0.900, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+1.350, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[-0.30240659759213545,-0.096162001272929],[-0.1078588313701522,0.0054819534355317525],[0.030573251522089485,-0.05394460434724826],[0.8164634900249075,0.35314915547770237],[0.0314874263824382,0.03205823441289259],[-0.031062095506164584,-0.0077011826805945625],[0.05468107502433242,0.23773554543992245],[0.16283026392007216,0.05833167694622215]]`

## Page 16
- Circuit depth: 3; topology id: 0
- R angle range: [5.838992, 6.218992] rad
- G angle range: [2.553370, 2.830770] rad
- B angle range: [5.782480, 5.938280] rad
- Mean entanglement entropy: 0.540382 bits
- Page entropy sweep range: [0.399202, 0.663243] bits
- Measurement Shannon entropy: 2.296829 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+0.480, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+0.960, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.440, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.480, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+0.960, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RX(B_theta*1.07+1.440, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+0.480, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RX(G_theta*1.14+0.960, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+1.440, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))`
- Final statevector (real, imag): `[[-0.26934996004761963,-0.01101530865674963],[-0.4617470556921104,-0.4088574279435584],[0.026328017473351978,-0.27081343659339635],[-0.037493285743759285,-0.546839346202077],[0.009682019618864316,0.14635443919386146],[-0.014610461159800473,-0.18305133734912632],[0.08050004832708559,-0.049693887580927604],[-0.3174060116546186,-0.08689928460056767]]`

## Page 17
- Circuit depth: 4; topology id: 1
- R angle range: [3.433028, 3.825028] rad
- G angle range: [4.948953, 5.235113] rad
- B angle range: [3.939718, 4.100438] rad
- Mean entanglement entropy: 0.405656 bits
- Page entropy sweep range: [0.405494, 0.480681] bits
- Measurement Shannon entropy: 2.428688 bits
- Circuit sequence: `RY(R_theta*1.00+0.510, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.020, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+1.530, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.510, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RX(G_theta*1.07+1.020, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+1.530, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+0.510, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RY(G_theta*1.14+1.020, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+1.530, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+0.510, wire=0) -> RZ(R_phi*0.85+0.171, wire=0) -> RY(G_theta*1.21+1.020, wire=1) -> RZ(G_phi*0.85+0.171, wire=1) -> RX(B_theta*1.21+1.530, wire=2) -> RZ(B_phi*0.85+0.171, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[-0.1137832896590089,0.5523713328633778],[0.17996957441877784,0.005325243178499152],[-0.35799524426622936,0.015394184202084198],[0.018487331091663544,0.012482512559776083],[0.15974015352845417,-0.5019496143129593],[-0.0706581814547159,0.3566943571803184],[0.2572244260174773,0.055679124828044144],[-0.11483337994157947,0.1687650642138511]]`

## Page 18
- Circuit depth: 2; topology id: 2
- R angle range: [1.027065, 1.431065] rad
- G angle range: [1.061351, 1.356271] rad
- B angle range: [2.096956, 2.262596] rad
- Mean entanglement entropy: 0.773200 bits
- Page entropy sweep range: [0.687727, 0.795233] bits
- Measurement Shannon entropy: 2.047399 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+0.540, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.080, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.620, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+0.540, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+1.080, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+1.620, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[0.08561480512657764,-0.5284328430961495],[0.1056837876660887,-0.21739067506346116],[-0.003143732459672116,0.03353729671843595],[0.009898908439961955,0.2159480486915342],[-0.07712918048193003,-0.06007119638979852],[0.1054763911098393,-0.016124761356093645],[0.650391170375755,0.10467525032061871],[0.2933129255087256,-0.25728213020483853]]`

## Page 19
- Circuit depth: 3; topology id: 3
- R angle range: [4.904287, 5.320287] rad
- G angle range: [3.456934, 3.760614] rad
- B angle range: [0.254193, 0.424753] rad
- Mean entanglement entropy: 0.505016 bits
- Page entropy sweep range: [0.504335, 0.570352] bits
- Measurement Shannon entropy: 1.968713 bits
- Circuit sequence: `RX(R_theta*1.00+0.570, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.140, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.710, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.570, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+1.140, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RX(B_theta*1.07+1.710, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+0.570, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RX(G_theta*1.14+1.140, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+1.710, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))`
- Final statevector (real, imag): `[[0.013727394831774814,0.03825505312950234],[-0.06803639372191202,0.633024713500392],[-0.32082575092160354,0.22910716578687532],[-0.29279330194837455,-0.5126806016038545],[-0.004939593267422827,0.1725315928242368],[-0.1257287238823725,0.04994605986495418],[0.15364542809215598,0.08616922183612648],[0.09442825639860693,0.031107539135098488]]`

## Page 20
- Circuit depth: 4; topology id: 0
- R angle range: [2.498324, 2.926324] rad
- G angle range: [5.852517, 6.164957] rad
- B angle range: [4.694616, 4.870096] rad
- Mean entanglement entropy: 0.638422 bits
- Page entropy sweep range: [0.542798, 0.745948] bits
- Measurement Shannon entropy: 2.694563 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+0.600, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.200, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+1.800, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.600, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RX(G_theta*1.07+1.200, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+1.800, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+0.600, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RY(G_theta*1.14+1.200, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+1.800, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+0.600, wire=0) -> RZ(R_phi*0.85+0.342, wire=0) -> RY(G_theta*1.21+1.200, wire=1) -> RZ(G_phi*0.85+0.342, wire=1) -> RX(B_theta*1.21+1.800, wire=2) -> RZ(B_phi*0.85+0.342, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[0.27104461086840326,-0.14098793878124677],[-0.3111071653747669,0.21614063498385516],[-0.2777238524865879,0.350780365192016],[0.22004531591307705,0.4889930640204292],[-0.17788263158213274,-0.041429692114299255],[0.22835475335642264,0.2970264957846903],[0.23652592639503195,-0.10072395650829453],[-0.05776402966315526,-0.17968144606091255]]`

## Page 21
- Circuit depth: 2; topology id: 1
- R angle range: [0.092361, 0.532361] rad
- G angle range: [1.964915, 2.286115] rad
- B angle range: [2.851854, 3.032254] rad
- Mean entanglement entropy: 0.219292 bits
- Page entropy sweep range: [0.168870, 0.324287] bits
- Measurement Shannon entropy: 2.064194 bits
- Circuit sequence: `RY(R_theta*1.00+0.630, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.260, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.890, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+0.630, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+1.260, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+1.890, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[-0.6078821584403411,-0.3315366155499022],[0.4706068498790016,-0.029721944351567525],[0.19312793885517038,-0.12099797342803828],[-0.009024540000969791,0.1021500039362997],[-0.22393106075399039,-0.28554195221941203],[0.06397762137506144,0.2996941726759499],[0.07136581649190746,-0.03423836493300739],[-0.026579313631086492,-0.05650408811444462]]`

## Page 22
- Circuit depth: 3; topology id: 2
- R angle range: [4.035583, 4.355583] rad
- G angle range: [4.408678, 4.642278] rad
- B angle range: [1.036151, 1.167351] rad
- Mean entanglement entropy: 0.310182 bits
- Page entropy sweep range: [0.093350, 0.523661] bits
- Measurement Shannon entropy: 1.720210 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+0.660, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.320, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+1.980, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.660, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+1.320, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RX(B_theta*1.07+1.980, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+0.660, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RX(G_theta*1.14+1.320, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+1.980, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))`
- Final statevector (real, imag): `[[-0.03894855207664813,0.022473281664554142],[0.44616973781959557,-0.19442933224851222],[0.03937645716905093,0.004857597683842591],[0.039527914061716685,-0.14741058574665483],[-0.014628153616036746,-0.026431824272533846],[-0.11251406760806676,-0.6140725919320003],[0.001077917923934387,-0.0029760770358196703],[0.17227472621814785,-0.5620458480262667]]`

## Page 23
- Circuit depth: 4; topology id: 3
- R angle range: [1.629620, 1.961620] rad
- G angle range: [0.521076, 0.763436] rad
- B angle range: [5.476574, 5.612694] rad
- Mean entanglement entropy: 0.420623 bits
- Page entropy sweep range: [0.203340, 0.654875] bits
- Measurement Shannon entropy: 2.166177 bits
- Circuit sequence: `RY(R_theta*1.00+0.690, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.380, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.070, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.690, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RX(G_theta*1.07+1.380, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+2.070, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+0.690, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RY(G_theta*1.14+1.380, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+2.070, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+0.690, wire=0) -> RZ(R_phi*0.85+0.114, wire=0) -> RY(G_theta*1.21+1.380, wire=1) -> RZ(G_phi*0.85+0.114, wire=1) -> RX(B_theta*1.21+2.070, wire=2) -> RZ(B_phi*0.85+0.114, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[0.3557957946431965,-0.440572997724811],[0.22519906257296446,-0.020691782525082525],[0.592385829907886,-0.22132255988925986],[0.24543403826853372,0.13250599131898272],[-0.05704965534316776,0.04134901409080754],[0.22151682233782524,-0.1847876641240369],[0.03327546747829338,-0.048578655489646544],[0.1343134871923778,-0.201925292609389]]`

## Page 24
- Circuit depth: 2; topology id: 0
- R angle range: [5.506842, 5.850842] rad
- G angle range: [2.916659, 3.167779] rad
- B angle range: [3.633812, 3.774852] rad
- Mean entanglement entropy: 0.937364 bits
- Page entropy sweep range: [0.899347, 0.949589] bits
- Measurement Shannon entropy: 2.238544 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+0.720, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.440, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.160, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+0.720, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+1.440, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+2.160, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[-0.3974560371386538,0.26977200457830086],[-0.021861337027009643,0.060792485684602764],[0.10320307287810632,-0.08927767124518995],[-0.2804612435012519,-0.3304578226162505],[-0.22038706235349564,0.5283402078657715],[-0.0962642759370259,-0.09761362180541733],[0.02733845664114352,-0.08306025044233044],[0.4445943883572221,0.08231787283837885]]`

## Page 25
- Circuit depth: 3; topology id: 1
- R angle range: [3.100878, 3.456878] rad
- G angle range: [5.312243, 5.572123] rad
- B angle range: [1.791050, 1.937010] rad
- Mean entanglement entropy: 0.797964 bits
- Page entropy sweep range: [0.732233, 0.857129] bits
- Measurement Shannon entropy: 2.271953 bits
- Circuit sequence: `RX(R_theta*1.00+0.750, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.500, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.250, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.750, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+1.500, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RX(B_theta*1.07+2.250, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+0.750, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RX(G_theta*1.14+1.500, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+2.250, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))`
- Final statevector (real, imag): `[[-0.1925903542785199,-0.18289854287748178],[-0.11710976283527962,0.08781592255319229],[-0.23930114750231296,0.09615592566307533],[6.587213280493524e-05,-0.06723216078851874],[-0.18348070471933567,0.06749394289088852],[-0.0506640997331617,-0.6533305131917938],[-0.10331777062423564,0.3595617802028836],[0.47056330204705554,0.08934376354364297]]`

## Page 26
- Circuit depth: 4; topology id: 2
- R angle range: [0.694915, 1.062915] rad
- G angle range: [1.424641, 1.693281] rad
- B angle range: [-0.051713, 0.099167] rad
- Mean entanglement entropy: 0.523312 bits
- Page entropy sweep range: [0.456596, 0.604835] bits
- Measurement Shannon entropy: 2.133530 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+0.780, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.560, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.340, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+0.780, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RX(G_theta*1.07+1.560, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+2.340, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+0.780, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RY(G_theta*1.14+1.560, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+2.340, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+0.780, wire=0) -> RZ(R_phi*0.85+0.285, wire=0) -> RY(G_theta*1.21+1.560, wire=1) -> RZ(G_phi*0.85+0.285, wire=1) -> RX(B_theta*1.21+2.340, wire=2) -> RZ(B_phi*0.85+0.285, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[0.16709644292969053,-0.05228234678791192],[0.09693120236187307,-0.1455164215974255],[-0.4691903349064492,0.3731873519179782],[-0.23457235494893638,0.5395827504199501],[-0.15170925614466627,0.26817746435449324],[-0.08173827742107902,0.018279186521218748],[-0.3586627751561407,-0.04085356482177772],[0.008566891065129699,-0.029343255842504266]]`

## Page 27
- Circuit depth: 2; topology id: 3
- R angle range: [4.572137, 4.952137] rad
- G angle range: [3.820224, 4.097624] rad
- B angle range: [4.388710, 4.544510] rad
- Mean entanglement entropy: 0.796228 bits
- Page entropy sweep range: [0.744016, 0.843507] bits
- Measurement Shannon entropy: 1.922887 bits
- Circuit sequence: `RY(R_theta*1.00+0.810, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.620, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.430, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+0.810, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+1.620, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+2.430, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[-0.7451755060098036,0.007464533249561926],[0.15183978072439552,0.11536573965532547],[0.029844971405751347,-0.23390023832843976],[0.21974907435470042,-0.3801808075422409],[-0.05674657626028861,-0.06278926124526078],[-0.08396572849587575,-0.06859033431320918],[-0.01318620857156253,-0.11421813389453864],[-0.11260356739212166,-0.3391891254358115]]`

## Page 28
- Circuit depth: 3; topology id: 0
- R angle range: [2.166174, 2.558174] rad
- G angle range: [-0.067378, 0.218782] rad
- B angle range: [2.545948, 2.706668] rad
- Mean entanglement entropy: 0.249945 bits
- Page entropy sweep range: [0.116617, 0.513744] bits
- Measurement Shannon entropy: 2.125445 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+0.840, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.680, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.520, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.840, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+1.680, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RX(B_theta*1.07+2.520, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+0.840, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RX(G_theta*1.14+1.680, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+2.520, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))`
- Final statevector (real, imag): `[[0.14879492314957815,0.0138696850640249],[-0.024618490051898298,-0.0899340612814685],[0.05482838599016406,0.07645799820948994],[0.04195486550806949,-0.06014242637128628],[0.14619007561971453,-0.4819164745027543],[0.3008704525344462,0.085977900784991],[-0.2577341207755321,-0.5612020835027713],[0.31948575297441134,-0.34607533938154944]]`

## Page 29
- Circuit depth: 4; topology id: 1
- R angle range: [6.043396, 6.447396] rad
- G angle range: [2.328205, 2.623125] rad
- B angle range: [0.703185, 0.868825] rad
- Mean entanglement entropy: 0.886715 bits
- Page entropy sweep range: [0.877638, 0.892491] bits
- Measurement Shannon entropy: 2.591407 bits
- Circuit sequence: `RY(R_theta*1.00+0.870, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.740, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.610, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+0.870, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RX(G_theta*1.07+1.740, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+2.610, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+0.870, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RY(G_theta*1.14+1.740, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+2.610, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+0.870, wire=0) -> RZ(R_phi*0.85+0.057, wire=0) -> RY(G_theta*1.21+1.740, wire=1) -> RZ(G_phi*0.85+0.057, wire=1) -> RX(B_theta*1.21+2.610, wire=2) -> RZ(B_phi*0.85+0.057, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[-0.32996439181364773,0.3885173348102446],[-0.2325809673601992,0.20912442948569887],[0.25350496167646414,-0.03336423311498648],[0.007056877438030603,0.4613507080305072],[0.032743135284527804,0.08129695697172777],[-0.14461020555602122,-0.33293392022302537],[0.18064091374714517,-0.412814957791264],[0.10651648397307603,-0.10122810368155197]]`

## Page 30
- Circuit depth: 2; topology id: 2
- R angle range: [3.637433, 4.053433] rad
- G angle range: [4.723788, 5.027468] rad
- B angle range: [5.143608, 5.314168] rad
- Mean entanglement entropy: 0.945941 bits
- Page entropy sweep range: [0.890525, 0.957476] bits
- Measurement Shannon entropy: 2.184139 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+0.900, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.800, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.700, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+0.900, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+1.800, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+2.700, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[0.23562315442812448,0.10198348719493044],[-0.4143208908357606,0.4031862769313449],[0.05121677733097229,-0.029468036471457855],[-0.28909711142734784,-0.04585427002603241],[-0.19333833894911984,-0.1129926777279098],[0.03062528915941124,0.09512414998933705],[-0.4751628168164951,0.4018793336769445],[-0.05142801064216665,0.2462188725586499]]`

## Page 31
- Circuit depth: 3; topology id: 3
- R angle range: [1.231470, 1.659470] rad
- G angle range: [0.836186, 1.148626] rad
- B angle range: [3.300846, 3.476326] rad
- Mean entanglement entropy: 0.829892 bits
- Page entropy sweep range: [0.595047, 0.904414] bits
- Measurement Shannon entropy: 1.925787 bits
- Circuit sequence: `RX(R_theta*1.00+0.930, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.860, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.790, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+0.930, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+1.860, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RX(B_theta*1.07+2.790, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+0.930, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RX(G_theta*1.14+1.860, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+2.790, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))`
- Final statevector (real, imag): `[[0.10841359925427335,0.1036347929069964],[-0.016182954134150936,-0.5309225051207175],[-0.1888321376616991,0.13583165959664914],[-0.08783209684172982,-0.10870216358421494],[0.06495402580503383,-0.7130565225965092],[0.028480194883221614,0.0777086850496482],[-0.013533153367059642,0.13459718655230435],[-0.24523753284179958,0.15416836796469274]]`

## Page 32
- Circuit depth: 4; topology id: 0
- R angle range: [5.108692, 5.548692] rad
- G angle range: [3.231769, 3.552969] rad
- B angle range: [1.458084, 1.638484] rad
- Mean entanglement entropy: 0.541351 bits
- Page entropy sweep range: [0.336393, 0.686416] bits
- Measurement Shannon entropy: 2.401382 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+0.960, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+1.920, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+2.880, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+0.960, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RX(G_theta*1.07+1.920, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+2.880, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+0.960, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RY(G_theta*1.14+1.920, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+2.880, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+0.960, wire=0) -> RZ(R_phi*0.85+0.228, wire=0) -> RY(G_theta*1.21+1.920, wire=1) -> RZ(G_phi*0.85+0.228, wire=1) -> RX(B_theta*1.21+2.880, wire=2) -> RZ(B_phi*0.85+0.228, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[-0.6618628699660212,0.14954563431020948],[-0.2561970469277396,-0.027395883319725478],[-0.2135771847604334,-0.04307100210723147],[-0.1781412418415916,0.17107345308368305],[0.429672113621601,0.0577313955747664],[0.201463029407015,0.1433948315269177],[0.11277906794047007,-0.1815203069108851],[-0.1286461270633378,-0.23107659919103662]]`

## Page 33
- Circuit depth: 2; topology id: 1
- R angle range: [2.768729, 3.088729] rad
- G angle range: [5.675533, 5.909133] rad
- B angle range: [5.925567, 6.056767] rad
- Mean entanglement entropy: 0.786296 bits
- Page entropy sweep range: [0.716305, 0.838051] bits
- Measurement Shannon entropy: 2.483124 bits
- Circuit sequence: `RY(R_theta*1.00+0.990, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+1.980, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+2.970, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+0.990, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+1.980, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+2.970, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[0.3678835838055003,-0.04343565260203333],[0.07426750703512357,-0.11681314741167004],[-0.06137862130558536,-0.3233170909125628],[0.047875121511878505,0.03771236585559614],[0.3861866887384888,-0.10030364019364743],[0.5371761054773513,0.2841313851693279],[-0.11146856656396391,-0.35485925645099337],[-0.09903712429609168,0.23441424076560974]]`

## Page 34
- Circuit depth: 3; topology id: 2
- R angle range: [0.362765, 0.694765] rad
- G angle range: [1.787931, 2.030291] rad
- B angle range: [4.082804, 4.218924] rad
- Mean entanglement entropy: 0.579602 bits
- Page entropy sweep range: [0.486201, 0.654395] bits
- Measurement Shannon entropy: 2.017786 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+1.020, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.040, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.060, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.020, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+2.040, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RX(B_theta*1.07+3.060, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+1.020, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RX(G_theta*1.14+2.040, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+3.060, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))`
- Final statevector (real, imag): `[[-0.318828094504034,-0.5122683494788225],[0.1743626472855628,0.029543869689178624],[0.23840206588098703,-0.13016857945747215],[-0.01543632934425855,0.09080757970296352],[-0.4192482070302956,0.48095133314073935],[-0.07412996999524132,0.13774757777299815],[0.22072236828777947,0.19632776543294256],[0.04986068786827677,0.032999625212173145]]`

## Page 35
- Circuit depth: 4; topology id: 3
- R angle range: [4.239987, 4.583987] rad
- G angle range: [4.183514, 4.434634] rad
- B angle range: [2.240042, 2.381082] rad
- Mean entanglement entropy: 0.562603 bits
- Page entropy sweep range: [0.432251, 0.646293] bits
- Measurement Shannon entropy: 2.118935 bits
- Circuit sequence: `RY(R_theta*1.00+1.050, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.100, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.150, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+1.050, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RX(G_theta*1.07+2.100, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+3.150, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+1.050, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RY(G_theta*1.14+2.100, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+3.150, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+1.050, wire=0) -> RZ(R_phi*0.85+0.000, wire=0) -> RY(G_theta*1.21+2.100, wire=1) -> RZ(G_phi*0.85+0.000, wire=1) -> RX(B_theta*1.21+3.150, wire=2) -> RZ(B_phi*0.85+0.000, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[0.6862110858891266,-0.2208801357647304],[-0.02902528370778629,-0.18916363426657956],[-0.3017069146623537,-0.30814396119036136],[-0.1860652083432906,-0.017845939844618033],[-0.22429418980483024,0.027994941704096603],[-0.1145579717152521,0.014840269669703091],[-0.35017595981342964,0.07927384467702067],[-0.11192716448079137,-0.1300456183336547]]`

## Page 36
- Circuit depth: 2; topology id: 0
- R angle range: [1.834024, 2.190024] rad
- G angle range: [0.295912, 0.555792] rad
- B angle range: [0.397279, 0.543239] rad
- Mean entanglement entropy: 0.883924 bits
- Page entropy sweep range: [0.820352, 0.906263] bits
- Measurement Shannon entropy: 1.927572 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+1.080, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.160, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.240, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+1.080, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+2.160, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+3.240, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[0.31169165308413094,0.027654176589821004],[-0.08994759665969759,0.037202746705303366],[-0.022115603002113023,0.0035399498741491525],[-0.38250165562159305,0.5073977601495498],[-0.5890083560231424,0.03345171860564312],[0.34693556348435983,-0.08267588137836804],[0.021101561218171333,-0.09323889369332075],[-0.03453327959049147,-0.05259799056350032]]`

## Page 37
- Circuit depth: 3; topology id: 1
- R angle range: [5.711246, 6.079246] rad
- G angle range: [2.691495, 2.960135] rad
- B angle range: [4.837702, 4.988582] rad
- Mean entanglement entropy: 0.377750 bits
- Page entropy sweep range: [0.362800, 0.478058] bits
- Measurement Shannon entropy: 1.736532 bits
- Circuit sequence: `RX(R_theta*1.00+1.110, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.220, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.330, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+1.110, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RY(G_theta*1.07+2.220, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RX(B_theta*1.07+3.330, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+1.110, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RX(G_theta*1.14+2.220, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+3.330, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))`
- Final statevector (real, imag): `[[0.29395346723807253,0.20085180045998596],[-0.026229299342121662,0.0016879300548389713],[0.458687843895008,-0.28389873050354625],[0.7109442047299931,-0.10790643257076868],[0.058887411919467184,-0.06484152510254887],[-0.0063136283774273775,-0.0378821508383026],[0.12867962839592975,0.16240029765563324],[0.027537592101471838,0.10790230773175676]]`

## Page 38
- Circuit depth: 4; topology id: 2
- R angle range: [3.305283, 3.685283] rad
- G angle range: [5.087078, 5.364478] rad
- B angle range: [2.994940, 3.150740] rad
- Mean entanglement entropy: 0.847374 bits
- Page entropy sweep range: [0.847302, 0.852384] bits
- Measurement Shannon entropy: 2.523776 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+1.140, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.280, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.420, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.140, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RX(G_theta*1.07+2.280, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+3.420, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+1.140, wire=0) -> RZ(R_phi*0.90+0.114, wire=0) -> RY(G_theta*1.14+2.280, wire=1) -> RZ(G_phi*0.90+0.114, wire=1) -> RY(B_theta*1.14+3.420, wire=2) -> RZ(B_phi*0.90+0.114, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+1.140, wire=0) -> RZ(R_phi*0.85+0.171, wire=0) -> RY(G_theta*1.21+2.280, wire=1) -> RZ(G_phi*0.85+0.171, wire=1) -> RX(B_theta*1.21+3.420, wire=2) -> RZ(B_phi*0.85+0.171, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[0.3293375165337459,-0.035278159340758786],[0.09885901582587112,0.08927190017426176],[0.4320805502491575,-0.12409605566543105],[-0.5761054841027096,-0.10562298241349011],[0.16952093260991513,0.21473307228195726],[0.3776374769778471,-0.15464433369295433],[0.1595438636663491,-0.21066188724233487],[0.04411683742741683,-0.119377363611607]]`

## Page 39
- Circuit depth: 2; topology id: 3
- R angle range: [0.899320, 1.291320] rad
- G angle range: [1.199476, 1.485636] rad
- B angle range: [1.152178, 1.312898] rad
- Mean entanglement entropy: 0.480264 bits
- Page entropy sweep range: [0.447700, 0.529613] bits
- Measurement Shannon entropy: 2.040700 bits
- Circuit sequence: `RY(R_theta*1.00+1.170, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.340, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.510, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0)) -> RX(R_theta*1.07+1.170, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+2.340, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RY(B_theta*1.07+3.510, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[0.2113691610717028,-0.1869655019527719],[-0.003274645990314351,0.4082988913657975],[-0.050731336003699015,-0.11710295621801367],[-0.5435153466707144,0.16666679634730822],[-0.02960610665155846,0.022357796072440823],[0.01952312278510592,0.1417273891273431],[-0.06673666629061971,0.02186002776730647],[-0.4670880344059445,0.4113729133964868]]`

## Page 40
- Circuit depth: 3; topology id: 0
- R angle range: [4.776542, 5.180542] rad
- G angle range: [3.595059, 3.889979] rad
- B angle range: [5.592601, 5.758241] rad
- Mean entanglement entropy: 0.817656 bits
- Page entropy sweep range: [0.797383, 0.823652] bits
- Measurement Shannon entropy: 1.912529 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+1.200, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.400, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.600, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+1.200, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RY(G_theta*1.07+2.400, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RX(B_theta*1.07+3.600, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.14+1.200, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RX(G_theta*1.14+2.400, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+3.600, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2))`
- Final statevector (real, imag): `[[-0.22071302483580318,-0.13393366114679003],[-0.6284380261864536,0.16767450776761764],[0.44227281171117705,-0.4188347542619627],[0.04019158373412288,0.0034491216365604826],[0.09888668645640235,0.21348763236385215],[0.00596738971094887,-0.02044927229186986],[0.07520220294829992,-0.08059336621398852],[0.00993584167140081,0.2637890809038934]]`

## Page 41
- Circuit depth: 4; topology id: 1
- R angle range: [2.370579, 2.786579] rad
- G angle range: [5.990643, 6.294323] rad
- B angle range: [3.749838, 3.920398] rad
- Mean entanglement entropy: 0.558131 bits
- Page entropy sweep range: [0.395090, 0.670627] bits
- Measurement Shannon entropy: 2.524022 bits
- Circuit sequence: `RY(R_theta*1.00+1.230, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.460, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.690, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+1.230, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RX(G_theta*1.07+2.460, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+3.690, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.14+1.230, wire=0) -> RZ(R_phi*0.90+0.228, wire=0) -> RY(G_theta*1.14+2.460, wire=1) -> RZ(G_phi*0.90+0.228, wire=1) -> RY(B_theta*1.14+3.690, wire=2) -> RZ(B_phi*0.90+0.228, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.21+1.230, wire=0) -> RZ(R_phi*0.85+0.342, wire=0) -> RY(G_theta*1.21+2.460, wire=1) -> RZ(G_phi*0.85+0.342, wire=1) -> RX(B_theta*1.21+3.690, wire=2) -> RZ(B_phi*0.85+0.342, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[-0.1518775771913618,-0.6017037637192294],[0.11828233756040685,-0.23346797453809645],[-0.1247957371908958,-0.14683589755317422],[-0.049419761302452264,-0.24861073588496585],[0.36687212895997096,0.1472613583747209],[-0.2214810901342767,0.3721065063132967],[0.0014780905113766373,-0.18191006792662226],[0.21824466987412877,-0.1431119234178596]]`

## Page 42
- Circuit depth: 2; topology id: 2
- R angle range: [-0.035385, 0.392615] rad
- G angle range: [2.103040, 2.415480] rad
- B angle range: [1.907076, 2.082556] rad
- Mean entanglement entropy: 0.766807 bits
- Page entropy sweep range: [0.736555, 0.768429] bits
- Measurement Shannon entropy: 2.415923 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+1.260, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.520, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.780, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1)) -> RX(R_theta*1.07+1.260, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+2.520, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RY(B_theta*1.07+3.780, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[0.437404443072463,0.13884160476135282],[0.06880451284738073,0.057461366405570986],[0.17081085174315538,-0.4062460550049493],[-0.19567784488777354,-0.009310547963282113],[-0.3454357276606322,0.3451865991104112],[-0.0724403872521666,0.06184368172533838],[-0.23836252707949782,-0.4518615741029742],[-0.1573845284466521,0.12433195768363663]]`

## Page 43
- Circuit depth: 3; topology id: 3
- R angle range: [3.841838, 4.281838] rad
- G angle range: [4.498624, 4.819824] rad
- B angle range: [0.064314, 0.244714] rad
- Mean entanglement entropy: 0.806398 bits
- Page entropy sweep range: [0.662464, 0.807491] bits
- Measurement Shannon entropy: 2.554865 bits
- Circuit sequence: `RX(R_theta*1.00+1.290, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.580, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+3.870, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+1.290, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RY(G_theta*1.07+2.580, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RX(B_theta*1.07+3.870, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=2, target=1) -> RY(R_theta*1.14+1.290, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RX(G_theta*1.14+2.580, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+3.870, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=0, target=2) -> CZ(wires=(1,0))`
- Final statevector (real, imag): `[[0.12909068553071043,0.1486921013568166],[-0.4269918657455097,-0.33811657651404314],[0.13535242750799228,-0.1856676779559604],[-0.1941571444339048,-0.45346067197406137],[0.27799128813433105,0.03852179840848473],[0.12417919196543079,0.2353741354010447],[-0.13647979805429905,0.023493439080605104],[-0.32506141747513034,-0.3066543567165398]]`

## Page 44
- Circuit depth: 4; topology id: 0
- R angle range: [1.501874, 1.821874] rad
- G angle range: [0.659202, 0.892802] rad
- B angle range: [4.531796, 4.662996] rad
- Mean entanglement entropy: 0.120258 bits
- Page entropy sweep range: [0.109249, 0.224013] bits
- Measurement Shannon entropy: 1.576087 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+1.320, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.640, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+3.960, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.07+1.320, wire=0) -> RZ(R_phi*0.95+0.038, wire=0) -> RX(G_theta*1.07+2.640, wire=1) -> RZ(G_phi*0.95+0.038, wire=1) -> RY(B_theta*1.07+3.960, wire=2) -> RZ(B_phi*0.95+0.038, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.14+1.320, wire=0) -> RZ(R_phi*0.90+0.076, wire=0) -> RY(G_theta*1.14+2.640, wire=1) -> RZ(G_phi*0.90+0.076, wire=1) -> RY(B_theta*1.14+3.960, wire=2) -> RZ(B_phi*0.90+0.076, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.21+1.320, wire=0) -> RZ(R_phi*0.85+0.114, wire=0) -> RY(G_theta*1.21+2.640, wire=1) -> RZ(G_phi*0.85+0.114, wire=1) -> RX(B_theta*1.21+3.960, wire=2) -> RZ(B_phi*0.85+0.114, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[0.2958715925621255,0.4419655914360766],[0.42707114757157916,0.6263391832671067],[0.008602909525837312,-0.29611260426325803],[0.02218413252853012,-0.19528895900532828],[0.00578199431454354,0.01573105176939959],[-0.08584804804467502,-0.06551290765405787],[-0.01826980663868467,0.0593868606390824],[-0.008949507976647382,0.01287931681388984]]`

## Page 45
- Circuit depth: 2; topology id: 1
- R angle range: [5.379096, 5.711096] rad
- G angle range: [3.054785, 3.297145] rad
- B angle range: [2.689034, 2.825154] rad
- Mean entanglement entropy: 0.479784 bits
- Page entropy sweep range: [0.411992, 0.545560] bits
- Measurement Shannon entropy: 1.515252 bits
- Circuit sequence: `RY(R_theta*1.00+1.350, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.700, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.050, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0)) -> RX(R_theta*1.07+1.350, wire=0) -> RZ(R_phi*0.95+0.057, wire=0) -> RY(G_theta*1.07+2.700, wire=1) -> RZ(G_phi*0.95+0.057, wire=1) -> RY(B_theta*1.07+4.050, wire=2) -> RZ(B_phi*0.95+0.057, wire=2) -> CNOT(control=2, target=0)`
- Final statevector (real, imag): `[[0.6985557222308186,0.4108490662410412],[-0.06856442859094364,-0.0012830826806931248],[0.020960944062875235,-0.008580252565345541],[0.12863719196447304,0.012997470611121976],[0.36612952700935397,0.11854646300951541],[-0.09112787782392825,-0.3660023049768788],[-0.002155617855464864,-0.050898052330119806],[0.005163464118654884,0.16823431767361952]]`

## Page 46
- Circuit depth: 3; topology id: 2
- R angle range: [2.973133, 3.317133] rad
- G angle range: [5.450368, 5.701488] rad
- B angle range: [0.846272, 0.987312] rad
- Mean entanglement entropy: 0.714351 bits
- Page entropy sweep range: [0.614714, 0.805470] bits
- Measurement Shannon entropy: 2.743970 bits
- Circuit sequence: `H(wire=1) -> RX(R_theta*1.00+1.380, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.760, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.140, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.380, wire=0) -> RZ(R_phi*0.95+0.076, wire=0) -> RY(G_theta*1.07+2.760, wire=1) -> RZ(G_phi*0.95+0.076, wire=1) -> RX(B_theta*1.07+4.140, wire=2) -> RZ(B_phi*0.95+0.076, wire=2) -> CNOT(control=0, target=1) -> RY(R_theta*1.14+1.380, wire=0) -> RZ(R_phi*0.90+0.152, wire=0) -> RX(G_theta*1.14+2.760, wire=1) -> RZ(G_phi*0.90+0.152, wire=1) -> RY(B_theta*1.14+4.140, wire=2) -> RZ(B_phi*0.90+0.152, wire=2) -> CNOT(control=2, target=0) -> CZ(wires=(0,1))`
- Final statevector (real, imag): `[[0.16079699254400345,0.32723586827091994],[0.30188893202955175,0.012713471822393633],[-0.1616142442055241,-0.5285914156331382],[-0.315387320420773,-0.18694757389569736],[-0.1693583253352007,0.23825897270186655],[0.17461013584702384,0.05303593932937276],[-0.22754377042492835,0.3242676274255163],[0.24264079792313256,-0.035560355351295724]]`

## Page 47
- Circuit depth: 4; topology id: 3
- R angle range: [0.567170, 0.923170] rad
- G angle range: [1.562766, 1.822646] rad
- B angle range: [5.286695, 5.432655] rad
- Mean entanglement entropy: 0.826968 bits
- Page entropy sweep range: [0.648960, 0.872916] bits
- Measurement Shannon entropy: 2.797420 bits
- Circuit sequence: `RY(R_theta*1.00+1.410, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.820, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+4.230, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.07+1.410, wire=0) -> RZ(R_phi*0.95+0.095, wire=0) -> RX(G_theta*1.07+2.820, wire=1) -> RZ(G_phi*0.95+0.095, wire=1) -> RY(B_theta*1.07+4.230, wire=2) -> RZ(B_phi*0.95+0.095, wire=2) -> CNOT(control=2, target=1) -> CZ(wires=(0,2)) -> RX(R_theta*1.14+1.410, wire=0) -> RZ(R_phi*0.90+0.190, wire=0) -> RY(G_theta*1.14+2.820, wire=1) -> RZ(G_phi*0.90+0.190, wire=1) -> RY(B_theta*1.14+4.230, wire=2) -> RZ(B_phi*0.90+0.190, wire=2) -> CNOT(control=0, target=2) -> RY(R_theta*1.21+1.410, wire=0) -> RZ(R_phi*0.85+0.285, wire=0) -> RY(G_theta*1.21+2.820, wire=1) -> RZ(G_phi*0.85+0.285, wire=1) -> RX(B_theta*1.21+4.230, wire=2) -> RZ(B_phi*0.85+0.285, wire=2) -> CNOT(control=2, target=1)`
- Final statevector (real, imag): `[[0.035596736804003944,-0.17800769406614972],[0.1668113977303578,0.2977585308573332],[0.49663878967838,-0.09427395032939341],[0.0233638192506702,-0.348823233049827],[0.4128459819009097,0.08554953575691554],[-0.22280132818172227,0.02096455428220552],[-0.16299828097609137,0.29333877163451183],[-0.10411480545538776,-0.34857183980622847]]`

## Page 48
- Circuit depth: 2; topology id: 0
- R angle range: [4.444392, 4.812392] rad
- G angle range: [3.958349, 4.226989] rad
- B angle range: [3.443932, 3.594812] rad
- Mean entanglement entropy: 0.587174 bits
- Page entropy sweep range: [0.517552, 0.661080] bits
- Measurement Shannon entropy: 2.629119 bits
- Circuit sequence: `H(wire=0) -> RY(R_theta*1.00+1.440, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RX(G_theta*1.00+2.880, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.320, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.07+1.440, wire=0) -> RZ(R_phi*0.95+0.114, wire=0) -> RY(G_theta*1.07+2.880, wire=1) -> RZ(G_phi*0.95+0.114, wire=1) -> RY(B_theta*1.07+4.320, wire=2) -> RZ(B_phi*0.95+0.114, wire=2) -> CNOT(control=1, target=2)`
- Final statevector (real, imag): `[[0.09399372917907538,0.34611357663798475],[-0.4979398677617136,-0.2729466257561151],[-0.12826071233486133,0.3158750579763281],[-0.1461771800170476,-0.20895321705295541],[-0.18735788142613144,-0.04107472446758092],[-0.2135723612703092,-0.1263978134050254],[-0.1295999873060505,-0.1637970813874687],[-0.020703521374626558,-0.4745899021641173]]`

## Page 49
- Circuit depth: 3; topology id: 1
- R angle range: [2.038429, 2.418429] rad
- G angle range: [0.070747, 0.348147] rad
- B angle range: [1.601170, 1.756970] rad
- Mean entanglement entropy: 0.007052 bits
- Page entropy sweep range: [0.002841, 0.123829] bits
- Measurement Shannon entropy: 1.111864 bits
- Circuit sequence: `RX(R_theta*1.00+1.470, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+2.940, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RY(B_theta*1.00+4.410, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=1, target=2) -> RY(R_theta*1.07+1.470, wire=0) -> RZ(R_phi*0.95+0.000, wire=0) -> RY(G_theta*1.07+2.940, wire=1) -> RZ(G_phi*0.95+0.000, wire=1) -> RX(B_theta*1.07+4.410, wire=2) -> RZ(B_phi*0.95+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.14+1.470, wire=0) -> RZ(R_phi*0.90+0.000, wire=0) -> RX(G_theta*1.14+2.940, wire=1) -> RZ(G_phi*0.90+0.000, wire=1) -> RY(B_theta*1.14+4.410, wire=2) -> RZ(B_phi*0.90+0.000, wire=2) -> CNOT(control=1, target=2) -> CZ(wires=(2,0))`
- Final statevector (real, imag): `[[-0.0025419433175485847,-0.0003124646780419727],[-0.0053827331542641,0.0035205963988822896],[0.02114329090820458,-0.7229385924327696],[0.04081187496026025,-0.05619401865113885],[0.0020427623006829647,0.003800834780640077],[0.004651003629034902,0.00395350875534964],[0.654366079836303,-0.18231026278122334],[0.09949297717092143,0.025587424150077056]]`

## Page 50
- Circuit depth: 4; topology id: 2
- R angle range: [5.915651, 6.307651] rad
- G angle range: [2.466330, 2.752490] rad
- B angle range: [6.041593, 6.202313] rad
- Mean entanglement entropy: 0.703723 bits
- Page entropy sweep range: [0.599533, 0.783681] bits
- Measurement Shannon entropy: 2.201197 bits
- Circuit sequence: `H(wire=2) -> RY(R_theta*1.00+1.500, wire=0) -> RZ(R_phi*1.00+0.000, wire=0) -> RY(G_theta*1.00+3.000, wire=1) -> RZ(G_phi*1.00+0.000, wire=1) -> RX(B_theta*1.00+4.500, wire=2) -> RZ(B_phi*1.00+0.000, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.07+1.500, wire=0) -> RZ(R_phi*0.95+0.019, wire=0) -> RX(G_theta*1.07+3.000, wire=1) -> RZ(G_phi*0.95+0.019, wire=1) -> RY(B_theta*1.07+4.500, wire=2) -> RZ(B_phi*0.95+0.019, wire=2) -> CNOT(control=0, target=1) -> CZ(wires=(1,2)) -> RX(R_theta*1.14+1.500, wire=0) -> RZ(R_phi*0.90+0.038, wire=0) -> RY(G_theta*1.14+3.000, wire=1) -> RZ(G_phi*0.90+0.038, wire=1) -> RY(B_theta*1.14+4.500, wire=2) -> RZ(B_phi*0.90+0.038, wire=2) -> CNOT(control=2, target=0) -> RY(R_theta*1.21+1.500, wire=0) -> RZ(R_phi*0.85+0.057, wire=0) -> RY(G_theta*1.21+3.000, wire=1) -> RZ(G_phi*0.85+0.057, wire=1) -> RX(B_theta*1.21+4.500, wire=2) -> RZ(B_phi*0.85+0.057, wire=2) -> CNOT(control=0, target=1)`
- Final statevector (real, imag): `[[-0.036578042097792786,-0.00823031123279786],[-0.3139484171521342,-0.11259744538803289],[-0.24819847136318632,0.11734187786287911],[0.28123455443352613,0.03533314760144854],[-0.4653503967703059,-0.4430715187560579],[0.09754770925590833,-0.11760192696483379],[-0.12045532112930049,0.5149074531202503],[0.12260265021818946,-0.027566306193165697]]`
