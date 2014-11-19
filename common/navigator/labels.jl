module NavigatorLabels

using JSON

export make_ontology

function make_ontology(path::ASCIIString)
	data = JSON.parsefile(path)
	
	nodes = data["nodes"]
	edges = data["links"]
	
	nodenames = ASCIIString[]
	ontology = Dict{ASCIIString, Array{ASCIIString}}()
	
	for node in nodes
		push!(nodenames, node["name"])
		ontology[node["name"]] = ASCIIString[]
	end
	
	for edge in edges
		push!(ontology[nodenames[edge["source"] + 1]], nodenames[edge["target"] + 1])
	end
	
	return ontology
end
end