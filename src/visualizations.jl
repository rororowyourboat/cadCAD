using Graphs
using GraphRecipes
# using Plots

# Function to visualize a schema
function visualize_schema(schema::CompositeType)
    g = SimpleGraph()
    node_labels = String[]
    node_counter = Ref(0)

    function add_nodes(s::TypeCategory, parent_node::Int)
        node_counter[] += 1
        current_node = node_counter[]
        add_vertex!(g)

        if s isa CompositeType
            push!(node_labels, s.name)
            if parent_node != 0
                add_edge!(g, parent_node, current_node)
            end
            for (key, component) in s.components
                add_nodes(component, current_node)
            end
        elseif s isa BaseType
            push!(node_labels, s.name)
            if parent_node != 0
                add_edge!(g, parent_node, current_node)
            end
        end
        return current_node
    end

    add_nodes(schema, 0)

    if nv(g) > 0
        println("Graph structure:")
        for (i, label) in enumerate(node_labels)
            println("Node $i: $label")
        end
        for e in edges(g)
            println("Edge: $(src(e)) -> $(dst(e))")
        end
        return true
    else
        println("The schema graph is empty.")
        return false
    end
end
