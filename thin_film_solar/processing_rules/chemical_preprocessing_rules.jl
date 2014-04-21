module ChemicalPreprocessingRules

using DataPipelines
using TextPipelines

using StringUtils
using MutableStrings
using MutableStringUtils

export substitute_compounds,
       substitute_allotropes,
       substitute_hydrogenation

const elements = Set{ASCIIString}([
    "Ac", "Ag", "Al", "Am", "Ar", "As", "At", "Au",
    "B", "Ba", "Be", "Bh", "Bi", "Bk", "Br",
    "C", "Ca", "Cd", "Ce", "Cf", "Cl", "Cm", "Cn", "Co", "Cr", "Cs", "Cu",
    "Db", "Ds", "Dy",
    "Er", "Es", "Eu",
    "F", "Fe", "Fl", "Fm", "Fr",
    "Ga", "Gd", "Ge",
    "H", "He", "Hf", "Hg", "Ho", "Hs",
    "I", "In", "Ir",
    "K", "Kr",
    "La", "Li", "Lr", "Lu", "Lv",
    "Md", "Mg", "Mn", "Mo", "Mt",
    "N", "Na", "Nb", "Nd", "Ne", "Ni", "No", "Np",
    "O", "Os",
    "P", "Pa", "Pb", "Pd", "Pm", "Po", "Pr", "Pt", "Pu",
    "Ra", "Rb", "Re", "Rf", "Rh", "Rn", "Ru",
    "S", "Sb", "Sc", "Se", "Sg", "Si", "Sm", "Sn", "Sr",
    "Ta", "Tb", "Tc", "Te", "Th", "Ti", "Tl", "Tm",
    "U",
    "V",
    "W",
    "Xe",
    "Y", "Yb",
    "Zn", "Zr"
])

# non-comprehensive for elements
# ex. leaves "oxygen" as is instead of mapping it to "O"
const unigram_chems = (ASCIIString => ASCIIString)[
"aluminum" => "Al",
"antimony" => "Sb",
"bismuth" => "Bi",
"boron" => "B",
"bromine" => "Br",
"cadmium" => "Cd",
"cerium" => "Ce",
"chlorine" => "Cl",
"cobalt" => "Co",
"copper" => "Cu",
"fluorine" => "F",
"iron" => "Fe",
"gallium" => "Ga",
"germanium" => "Ge",
"gold" => "Au",
"indium" => "In",
"iodine" => "I",
"lanthanum" => "La",
"lithium" => "Li",
"magnesium" => "Mg",
"manganese" => "Mn",
"molybdenum" => "Mo",
"neodymium" => "Nd",
"nickel" => "Ni",
"nitrogen" => "N",
"niobium" => "Nb",
"palladium" => "Pd",
"phosphorus" => "P",
"platinum" => "Pt",
"ruthenium" => "Ru",
"silver" => "Ag",
"silicon" => "Si",
"sodium" => "Na",
"sulfer" => "S",
"tin" => "Sn",
"titanium" => "Ti",
"tungsten" => "W",
"ytterbium" => "Yb",
"yttrium" => "Y",
"zinc" => "Zn",
"zirconium" => "Zr",

"al" => "Al",
"ag" => "Ag",
"au" => "Au",
"b"  => "B",
"bi" => "Bi",
"br" => "Br",
"cd" => "Cd",
"ce" => "Ce",
"cl" => "Cl",
"co" => "Co",
"cu" => "Cu",
"f"  => "F",
"fe" => "Fe",
"ga" => "Ga",
"ge" => "Ge",
"la" => "La",
"li" => "Li",
"mg" => "Mg",
"mn" => "Mn",
"mo" => "Mo",
"na" => "Na",
"nb" => "Nb",
"nd" => "Nd",
"ni" => "Ni",
"pd" => "Pd",
"pt" => "Pt",
"ru" => "Ru",
"sb" => "Sb",
"si" => "Si",
"sn" => "Sn",
"ti" => "Ti",
"w"  => "W",
"yb" => "Yb",
"zn" => "Zn",
"zr" => "Zr",

"aluminium" => "Al",
"cupper" => "Cu",
"sulpher" => "S",

"ammonia" => "NH3",
"titania" => "TiO2",
"silica" => "SiO2",
"silane" => "SiH4",
"alumina" => "Al2O3",
"chalcocite" => "Cu2S",
"hematite" => "Fe2O3",

"silicon-carbide" => "SiC",
"silicon-germanium" => "SiGe",
"silicon-selenium" => "SiSe",
"silicon-oxide" => "SiO2",
"zinc-oxide" => "ZnO",

"SixGe1-x" => "SiGe",
"Si1-xGex" => "SiGe",

"a-si" => "a-Si",
"SnO(2)" => "SnO2",
"TiO(2)" => "TiO2",
"In(2)O(3)" => "In2O3",

"anatase-TiO2" => "anatase",
"rutile-TiO2" => "rutile",
"brookite-TiO2" => "brookite",
"TiO2-anatase" => "anatase",
"TiO2-rutile" => "rutile",
"TiO2-brookite" => "brookite",

"CHCl3" => "chloroform",

"buckminsterfullerene" => "fullerene",

"In2O3:Sn" => "ITO",
"SnO2:In" => "ITO",
"SnO2:F" => "FTO",
"ZnO:In" => "IZO",
"ZnO:in" => "IZO",
"ZnO:Al" => "AZO",
"Al:ZnO" => "AZO",
"ZnO:B" => "BZO",
"B:ZnO" => "BZO",
"ZnO:Ga" => "GZO",
"Ga:ZnO" => "GZO",

"CIGS2" => "CIGS",
"Cu-In-Ga-S" => "CIGS",
"Cu-In-Ga-Se" => "CIGSe",
"Cu:In:Ga:Se" => "CIGSe",
"Cu-Zn-Tn-S" => "CZTS",
"Cu-Zn-Tn-Se" => "CZTSe",
"Cu-In-S" => "CIS",
"Cu-In-Se" => "CISe",

"dimethylcadmium" => "DMCd",
"polydimethylsiloxane" => "PDMS",
"polymethylmethacrylate" => "PMMA",
"diethylzinc" => "DEZn",
"trimethylboron" => "TMB",

"In-Cu" => "Cu-In",
"CdS-CdTe" => "CdTe-CdS",
"InxSey" => "In2Se3",
"ZnInxSey" => "ZnIn2Se4",
"SiH(4)" => "SiH4",

"CuInGaSe2" => "CIGS",
"Cu(In,Ga)Se-2" => "CIGS",
"CuInGaSe(2)" => "CIGS",
"CIGSe" => "CIGS",
"CIGSe-2" => "CIGS",
"CIGSe(2)" => "CIGS",
"Cu(In,Ga)(S,Se)(2)" => "CIGSSe",
"Cu2ZnSnS4" => "CZTS",
"Cu2ZnSnS-4" => "CZTS",
"Cu2ZnSnSe4" => "CZTSe",
"Cu2ZnSnSe-4" => "CZTSe",
"Cu2ZnSn(S,Se)4" => "CZTSSe",
"Cu2ZnSn(S,Se)(4)" => "CZTSSe",
"CIS2" => "CIS",
"CuInS" => "CIS",
"CuInS2" => "CIS",
"CuInS(2)" => "CIS",
"CuInxSy" => "CIS",
"CISe2" => "CISe",
"CuInSe" => "CISe",
"CuInSe2" => "CISe",
"CuInSe(2)" => "CISe",
"CuInxSey" => "CISe",
"CuIn(S,Se)(2)" => "CISSe",
]

const bigram_chems = (ASCIIString => ASCIIString)[
"aluminum oxide" => "Al2O3",
"aluminum chloride" => "AlCl3",
"ammonium fluoride" => "NH4F",
"ammonium chloride" => "NH4Cl",
"ammonium bromide" => "NH4Br",
"ammonium hydroxide" => "NH4OH",
"antimony telluride" => "Sb2Te3",
"antimony trichloride" => "Sb2Cl3",
"bismuth sulfide" => "Bi2S3",
"cadmium oxide" => "CdO",
"cadmium sulfide" => "CdS",
"cadmium selenide" => "CdSe",
"cadmium telluride" => "CdTe",
"cadmium chloride" => "CdCl2",
"cadmium hydroxide" => "Cd(OH)2",
"carbon dioxide" => "CO2",
"carbon disulfide" => "CS2",
"cupric oxide" => "CuO",
"cuprous oxide" => "Cu2O",
"copper iodide" => "CuI",
"gallium arsenide" => "GaAs",
"gallium selenide" => "GaSe",
"gallium nitride" => "GaN",
"hydrogen sulfide" => "H2S",
"hydrogen peroxide" => "H2O2",
"indium oxide" => "In2O3",
"indium sulfide" => "In2S3",
"indium selenide" => "In2Se3",
"indium phosphide" => "InP",
"indium nitride" => "InN",
"indium(III) chloride" => "InCl3",
"lithium fluoride" => "LiF",
"lithium iodide" => "LiI",
"molybdenum trioxide" => "MoO3",
"nickel chloride" => "NiCl2",
"potassium hydroxide" => "KOH",
"silicon carbide" => "SiC",
"silicon dioxide" => "SiO2",
"silicon nitride" => "Si3N4",
"selenium dioxide" => "SeO2",
"sodium hydroxide" => "NaOH",
"sodium sulfide" => "Na2S",
"sodium borohydride" => "NaBH4",
"tin oxide" => "SnO2", # there is also SnO, but it doesn't appear in this corpus
"tin dioxide" => "SnO2",
"tin monosulfide" => "SnS",
"tin(II) chloride" => "SnCl2",
"tantalum oxide" => "Ta2O5",
"titanium dioxide" => "TiO2",
"titanium nitride" => "TiN",
"titanium tetrachloride" => "TiCl4",
"tungsten trioxide" => "WO3",
"tungsten disulfide" => "WS2",
"zinc oxide" => "ZnO",
"zinc sulfide" => "ZnS",
"zinc selenide" => "ZnSe",
"zinc telluride" => "ZnTe",
"zinc chloride" => "ZnCl2",
"zinc hydroxide" => "Zn(OH)2",
"zinc nitrate" => "Zn(NO3)2",
"zirconium dioxide" => "ZrO2",

"hydrofluoric acid" => "HF",
"hydrochloric acid" => "HCl",
"hydrobromic acid" => "HBr",
"hydroiodic acid" => "HI",
"nitric acid" => "HNO3",
"phosphoric acid" => "H3PO4",
"sulfuric acid" => "H2SO4",

"dimethyl sulfoxide" => "DMSO",
"dimethyl cadmium" => "DMCd",
"diethyl zinc" => "DEZn",

"anatase TiO2" => "anatase",
"rutile TiO2" => "rutile",
"brookite TiO2" => "brookite",
"TiO2 anatase" => "anatase",
"TiO2 rutile" => "rutile",
"TiO2 brookite" => "brookite",


"polyethylene terephthalate" => "PET",
"butyric acid methyl ester" => "PCBM",
"c61 butyric acid methylester" => "PCBM",
"titanium isopropoxide" => "TTIP",
"titanium tetraisopropoxide" => "TTIP",
"cetyltrimethylammonium bromide" => "CTAB",
"tetramethylammonium hydroxide" => "TMAOH",
"copper pthalocyanine" => "CuPc",
"Cu pthalocyanine" => "CuPc",

"CuInxGa1 xSe2" => "CIGS",
"CuIn1 xGaxSe2" => "CIGS",
"CuIn1 x,GaxSe2" => "CIGS",
"Cu(In,Ga)Se 2" => "CIGS",
"Cu2ZnSn(S, Se)(4)" => "CZTSSe",
"Cu2ZnSn(SxSe1 x)(4)" => "CZTSSe",
"Cu2ZnSn(S1 xSex)(4)" => "CZTSSe",
"Cu2ZnSn(SexS1 x)(4)" => "CZTSSe",
"Cu2ZnSn(Se1 xSx)(4)" => "CZTSSe",
]

const allotropes = (ASCIIString => ASCIIString)[
"amorphous" => "a",
"crystalline" => "c",
"microcrystalline" => "muc",
"nanocrystalline" => "nc",
"monocrystalline" => "mono",
"polycrystalline" => "poly",
"multicrystalline" => "mc",
]

const allotropes_inv = (ASCIIString => ASCIIString)[
"a" => "amorphous",
"c" => "crystalline",
"muc" => "microcrystalline",
"mono" => "monocrystalline",
"poly" => "polycrystalline",
"nc" => "nanocrystalline",
"mc" => "multicrystalline",
]

function substitute_compounds(input::TextAndPos,
                              state::BigramWindow,
                              output::DataProcessor{TextAndPos})
    if length(state.last.text) == 0
        shift!(state, input)
        return
    end

    if state.last.sentence_idx != input.sentence_idx
        offer(output, state.last)
        shift!(state, input)
        return
    end

    bigram = "$(state.last.text) $(input.text)"

    if (input.pos[1] <= state.last.pos[end] + 1 && haskey(bigram_chems, bigram))
        offer(output, TextAndPos(
            bigram_chems[bigram],
            range_cat(state.last.pos, input.pos),
            input.sentence_idx
        ))
        reset!(state)
    elseif haskey(unigram_chems, state.last.text)
        substitute!(state.last.text, unigram_chems[state.last.text])
        offer(output, state.last)
        shift!(state, input)
    else
        dash_idx = search(state.last.text, '-')
        if dash_idx > 0 && haskey(unigram_chems, state.last.text[1:dash_idx-1])
            offer(output, TextAndPos(
                unigram_chems[state.last.text[1:dash_idx-1]] * "-" * state.last.text[dash_idx+1:end],
                state.last.pos,
                state.last.sentence_idx
            ))
        else
            offer(output, state.last)
        end
        shift!(state, input)
    end
end

function substitute_allotropes(input::TextAndPos,
                               state::BigramWindow,
                               output::DataProcessor{TextAndPos})

    if length(state.last.text) == 0
        shift!(state, input)
        return
    end

    if (input.pos[1] <= state.last.pos[end] + 1
        && haskey(allotropes, state.last.text)
        && state.last.sentence_idx == input.sentence_idx
        && has_upper(input.text)
        && !('-' in input.text))

        offer(output, TextAndPos(
            allotropes[state.last.text] * "-" * input.text,
            range_cat(state.last.pos, input.pos),
            input.sentence_idx)
        )
        reset!(state)
    else
        offer(output, state.last)
        shift!(state, input)
    end
end

function substitute_hydrogenation(input::TextAndPos,
                                  state::BigramWindow,
                                  output::DataProcessor{TextAndPos})

    if length(state.last.text) == 0
        shift!(state, input)
        return
    end

    if (input.pos[1] <= state.last.pos[end] + 1
        && state.last.text == "hydrogenated"
        && state.last.sentence_idx == input.sentence_idx
        && has_upper(input.text)
        && !(':' in input.text))

        offer(output, TextAndPos(
            input.text * ":H", input.pos, input.sentence_idx
        ))
        reset!(state)
    else
        offer(output, state.last)
        shift!(state, input)
    end
end

end
