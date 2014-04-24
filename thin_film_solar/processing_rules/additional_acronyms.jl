module AdditionalAcronyms

export additional_ac_phrase,
       additional_phrase_ac,
       acs_that_are_the_canonical_form

const additional_ac_phrase = (ASCIIString => ASCIIString)[
"TCO" => "transparent conducting oxide",

"TPA" => "triphenylamine",
"TEA" => "triethanolamine",
"THF" => "tetrahydrofuran",
"PEG" => "polyethylene glycol",
"PEN" => "polyethylene napthalate",
"PMMA" => "polymethylmethacrylate",
"PDMS" => "polydimethylsiloxane",
"CuPc" => "copper pthalocyanine",
"CuPC" => "copper pthalocyanine",

"NRs" => "nanorod",
"NWs" => "nanowire",
"BHJ" => "bulk heterojunction",
"FET" => "field effect transistor",
"OFET" => "organic field effect transistor",

"CBD" => "chemical bath deposition",
"MW-CBD" => "microwave activated chemical bath deposition",
"US-CBD" => "ultrasonic chemical bath deposition",

"CVD" => "chemical vapor deposition",

"LPCVD" => "low pressure chemical vapor deposition",
"LP-CVD" => "low pressure chemical vapor deposition",
"APCVD" => "atmospheric pressure chemical vapor deposition",
"AP-CVD" => "atmospheric pressure chemical vapor deposition",

"HWCVD" => "hot wire chemical vapor deposition",
"HW-CVD" => "hot wire chemical vapor deposition",
"Cat-CVD" => "hot wire chemical vapor deposition",
"AACVD" => "aerosol assisted chemical vapor deposition",
"RTCVD" => "rapid thermal chemical vapor deposition",
"RT-CVD" => "rapid thermal chemical vapor deposition",
"OA-CVD" => "open atmosphere chemical vapor deposition",

"MOCVD" => "metal organic chemical vapor deposition",
"MOVPE" => "metal organic chemical vapor deposition",
"OMVPE" => "metal organic chemical vapor deposition",
"LP-MOCVD" => "low pressure metal organic chemical vapor deposition",
"LP-MOVPE" => "low pressure metal organic chemical vapor deposition",
"AP-MOCVD" => "atmospheric pressure metal organic chemical vapor deposition",
"AP-MOVPE" => "atmospheric pressure metal organic chemical vapor deposition",
"PA-MOCVD" => "plasma assisted metal organic chemical vapor deposition",
"Au-MOCVD" => "Au-catalyst assisted metal organic chemical vapor deposition",
"ECR-MOCVD" => "electron cyclotron resonance metal organic chemical vapor deposition",
"photoMOCVD" => "photoinduced metal organic chemical vapor deposition",

"PCVD" => "plasma enhanced chemical vapor deposition",
"P-CVD" => "plasma enhanced chemical vapor deposition",
"PECVD" => "plasma enhanced chemical vapor deposition",
"PE-CVD" => "plasma enhanced chemical vapor deposition",
"PACVD" => "plasma enhanced chemical vapor deposition",
"VHF-CVD" => "very high frequency plasma enhanced chemical vapor deposition",
"VHF-PECVD" => "very high frequency plasma enhanced chemical vapor deposition",
"RP-CVD" => "remote hydrogen plasma chemical vapor deposition",
"ICP-CVD" => "inductively coupled plasma chemical vapor deposition",

"ECR-CVD" => "electron cyclotron resonance chemical vapor deposition",
"MWECR-CVD" => "electron cyclotron resonance chemical vapor deposition", # omitting "microwave"

"ESAVD" => "electrostatic spray assisted vapor deposition",

"ALD" => "atomic layer deposition",
"AL-CVD" => "atomic layer deposition",

"EBID" => "electron beam-induced deposition",
"FLC" => "flash lamp crystallization",
"CSVT" => "close spaced vapor transport",
"CCSVT" => "close spaced vapor transport",
"MFD" => "modulated flux deposition",
"MBE" => "molecular beam epitaxy",
"HWE" => "hot wall expitaxy",
"ROMP" => "ring opening metathesis polymerization",
"RF-MS" => "radio frequency magnetron sputtering",
"DC-MS" => "direct current magnetron sputtering",

"XRD" => "x-ray diffraction",
"XPS" => "x-ray photoelectron spectroscopy",
"UPS" => "uv photoelectron spectroscopy",
"NMR" => "nuclear magnetic resonance",
"C-AFM" => "conductive atomic force microscopy",
"c-AFM" => "conductive atomic force microscopy",
"EDS" => "energy dispersive x-ray spectroscopy",
"EDX" => "energy dispersive x-ray spectroscopy",
"EDXRD" => "energy dispersive x-ray spectroscopy",
"EDXA" => "energy dispersive x-ray spectroscopy",
"FTIR" => "fourier transform infrared spectroscopy",
"PIXE" => "particle induced x-ray emission",
"EELS" => "electron energy loss spectrometry",
"XAFS" => "x-ray absorption fine structure",
"XANES" => "x-ray absorption near edge structure",
"NEXAFS" => "x-ray absorption near edge structure",
"TRPL" => "time-resolved photoluminescence",
"PLE" => "photoluminescence excitation",
"EELS" => "electron energy loss spectroscopy",
"DRIFT" => "diffuse reflectance infrared fourier transform",
"GIXS" => "grazing incidence x-ray scattering",
"SIMS" => "secondary ion mass spectroscopy",
"ToF-SIMS" => "time-of-flight secondary ion mass spectroscopy",

"VOC" => "open circuit voltage",
"V-OC" => "open circuit voltage",
"IPCE" => "induced photon-to-current efficiency",
"SCLC" => "space charge limited current",

"DFT" => "density functional theory",
"TDDFT" => "time-dependent density functional theory",
"TD-DFT" => "time-dependent density functional theory",

"kMC" => "kinetic Monte Carlo",
]

const additional_phrase_ac = (ASCIIString => ASCIIString)[
"transparent conducting oxide" => "TCO",
"transparent conductive oxide" => "TCO",
"conducting transparent oxide" => "TCO",
"conductive transparent oxide" => "TCO",

"indium tin oxide" => "ITO",
"fluorine tin oxide" => "FTO",
"fluorinated tin oxide" => "FTO",
"indium zinc oxide" => "IZO",
"aluminum zinc oxide" => "AZO",
"boron zinc oxide" => "BZO",
"gallium zinc oxide" => "GZO",

"copper indium gallium selenide" => "CIGS",
"copper indium gallium diselenide" => "CIGS",
"copper indium gallium di selenide" => "CIGS",
"copper zinc tin sulfide" => "CZTS",
"copper zinc tin selenide" => "CZTSe",
"copper indium sulfide" => "CIS",
"copper indium disulfide" => "CIS",
"copper indium selenide" => "CISe",
"copper indium diselenide" => "CISe",

"polyethylene terephthalate" => "PET",
"butyric acid methyl ester" => "PCBM",
"c61 butyric acid methylester" => "PCBM",
"titanium isopropoxide" => "TTIP",
"titanium tetraisopropoxide" => "TTIP",
"cetyltrimethylammonium bromide" => "CTAB",
"tetramethylammonium hydroxide" => "TMAOH",
"copper pthalocyanine" => "CuPc",
"Cu pthalocyanine" => "CuPc",

"sodalime glass" => "SLG",
"organic field effect transistor" => "OFET",

"layer by layer" => "LBL",
"molecular beam epitaxy" => "MBE",
"catalytic chemical vapor deposition" => "HW-CVD",
"close spaced vapor transport" => "CSVT",
"ring opening metathesis polymerization" => "ROMP",
"radio frequency magnetron sputtering" => "RF-MS",
"direct current magnetron sputtering" => "DC-MS",

"energy dispersive spectroscopy" => "EDS",
"energy dispersive x-ray spectroscopy" => "EDS",
"energy dispersive x-ray diffraction" => "EDS",
"energy dispersive x-ray analysis" => "EDS",
"fourier transform infrared spectroscopy" => "FTIR",
"particle induced x-ray emission" => "PIXE",
"proton induced x-ray emission" => "PIXE",
"near edge x-ray absorption fine structure spectroscopy" => "NEXAFS",
"x-ray absorption near edge structure" => "XANES",

"space charge limited current" => "SCLC",
"space charge limited conduction" => "SCLC",

"time dependent density functional theory" => "TD-DFT",
"kinetic Monte Carlo" => "kMC",
"kinetic monte carlo" => "kMC",
]

const acs_that_are_the_canonical_form = Set{ASCIIString}([
"ITO", "FTO", "IZO", "AZO", "BZO", "GZO",
"CIGS", "CIGSe", "CIGSSe",
"CZTS", "CZTSe", "CZTSSe",
"CIS", "CISe", "CISSe",
"PCBM",
])

end
