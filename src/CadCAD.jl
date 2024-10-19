module CadCAD

export run_exp

include("spaces.jl")

using .Spaces
using Logging, StaticArrays

"""
cadCAD.jl v0.0.2
"""
function intro()
    println(raw"""
      ____          _  ____    _    ____    _ _
     / ___|__ _  __| |/ ___|  / \  |  _ \  (_) |
    | |   / _` |/ _` | |     / _ \ | | | | | | |
    | |__| (_| | (_| | |___ / ___ \| |_| | | | |
     \____\__,_|\__,_|\____/_/   \_\____(_)/ |_|
                                         |__/ v0.0.2
          """)

    @info """
    \nStarting simulation...\n
    """
end

"""
Run an experiment with the given initial state, experiment parameters, pipeline, and function dictionary.

# Parameters
- `init_state::T`: The initial state of the experiment.
- `experiment_params::NamedTuple`: The parameters for the experiment.
- `pipeline::String`: The pipeline of functions to apply.
- `func_dict::Dict{String, Function}`: A dictionary of functions to use in the pipeline.

# Returns
- `Vector{SVector{experiment_params.n_steps, T}}`: The result matrix of the experiment.

# Throws
- `Error`: If a function in the pipeline is not found in `func_dict`.
"""
function run_exp(init_state::T, experiment_params::NamedTuple,
        pipeline::String, func_dict::Dict{String, Function}) where {T <: Point}
    intro()

    # Split the pipeline string into function names
    func_names = split(pipeline, " > ")
    result_matrix = Vector{SVector{experiment_params.n_steps, T}}(undef, experiment_params.n_runs)

    for i in 1:experiment_params.n_runs
        current_state = init_state
        result = MVector{experiment_params.n_steps, T}(undef)
        result[1] = current_state

        for j in 1:(experiment_params.n_steps - 1)
            # Apply each function in the pipeline with error handling
            for func_name in func_names
                if haskey(func_dict, func_name)
                    current_state = func_dict[func_name](current_state)
                else
                    error("Function '$func_name' not found in func_dict.")
                end
            end
            result[j + 1] = current_state
        end

        result_matrix[i] = SVector(result)
    end

    return result_matrix
end

"""
Compile the pipeline string into an expression.

# Parameters
- `pipeline::String`: The pipeline string to compile.

# Returns
- `Expr`: The compiled expression.
"""
function pipeline_compile(pipeline::String)::Expr
    return Meta.parse(pipeline)
end

end
