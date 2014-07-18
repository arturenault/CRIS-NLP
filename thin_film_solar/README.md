To run term extractor,

    ln -s ~/Dropbox/cris_lab_data
    mkdir output
    julia preprocess.clj

If julia throws any package errors, run

    julia -e 'Pkg.add(\"pkg-name"\)" 
    
Once preprocess is finished 

    julia extract_terms.clj
    
    
To view navigator, 

    julia navigator/navigator_server.jl

and point your browser at [this link](http://localhost:8000/navigator.html)
