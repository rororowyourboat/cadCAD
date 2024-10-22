module CadCAD

using Graphs
using GraphRecipes

include("types.jl")
include("operations.jl")
include("simulation.jl")
include("visualizations.jl")

export BaseType, CompositeType, Port, Terminal, Block
export TypeCategory
export select_component, combine_schemas, schemas_are_congruent, identity_block
export type_check, compose_blocks, simulate_system
export visualize_schema
export is_member, similarity, compose_schema_morphisms, tau, tau_inverse

end
