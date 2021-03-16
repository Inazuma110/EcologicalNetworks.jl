import Base: eltype

"""
All networks in the package belong to the `AbstractEcologicalNetwork` type. They
all have a field `A` to represent interactions as a *matrix*, and a number of
fields for species. See the documentation for `AbstractBipartiteNetwork` and
`AbstractUnipartiteNetwork`, as well as `AllowedSpeciesTypes` for the allowed
types for species.

Note that *all* species in a network (including both levels of a bipartite
network) *must* have the same type. For example, `["a", :b, "c"]` is not a valid
array of species, as not all its elements have the same type.
"""
abstract type AbstractEcologicalNetwork end

"""
This abstract type groups all unipartite networks, regardless of the type of
information. Unipartite networks have *a single* field for species, named `S`,
which has the same number of elements as the size of the matrix.

Any unipartite network can be declared (we'll use the example of a binary
network) either using `UnipartiteNetwork(A, S)` (assuming `A` is a matrix of
interactions and `S` is a vector of species names), or `UnipartiteNetwork(A)`,
in which case the species will be named automatically.
"""
abstract type AbstractUnipartiteNetwork <: AbstractEcologicalNetwork end

"""
This abstract type groups all bipartite networks, regardless of the type of
information. Bipartite networks have *two* fields for species, named `T` (for
top, corresponding to matrix *rows*), and `B` (for bottom, matrix *columns*).

Any bipartite network can be declared (we'll use the example of a binary
network) either using `BipartiteNetwork(A, T, B)` (assuming `A` is a matrix of
interactions and `T` and `B` are vectors of species names for the top and bottom
level), or `BipartiteNetwork(A)`, in which case the species will be named
automatically.
"""
abstract type AbstractBipartiteNetwork <: AbstractEcologicalNetwork end

"""
A bipartite deterministic network is a matrix of boolean values.
"""
mutable struct BipartiteNetwork{W, ST} <: AbstractBipartiteNetwork
    edges::SparseMatrixCSC{W,Int64}
    T::Vector{ST}
    B::Vector{ST}
    function BipartiteNetwork{W, NT}(edges::M, T::Vector{NT}, B::Vector{NT}) where {M<:SparseMatrixCSC, NT, W}
        dropzeros!(edges)
        check_bipartiteness(edges, T, B)
        new{eltype(edges),NT}(edges, T, B)
    end
end

function BipartiteNetwork(A::M, T::Union{Vector{TT},Nothing}=nothing, B::Union{Vector{TT},Nothing}=nothing) where {M <: AbstractMatrix, TT}
    if isnothing(B)
        B = "b".*string.(1:size(A, 2))
    else
        _check_species_validity(TT)
    end
    if isnothing(T)
        T = "t".*string.(1:size(A, 1))
    else
        _check_species_validity(TT)
    end
    allunique(T) || throw(ArgumentError("All top-level species must be unique"))
    allunique(B) || throw(ArgumentError("All bottom-level species must be unique"))
    allunique(vcat(B,T)) || throw(ArgumentError("Bipartite networks cannot share species across levels"))
    isequal(length(T))(size(A,1)) || throw(ArgumentError("The matrix has the wrong number of top-level species"))
    isequal(length(B))(size(A,2)) || throw(ArgumentError("The matrix has the wrong number of bottom-level species"))
    return BipartiteNetwork{eltype(M),eltype(T)}(sparse(A), T, B)
end

"""
An unipartite deterministic network is a matrix of boolean values.
"""
mutable struct UnipartiteNetwork{Bool, ST} <: AbstractUnipartiteNetwork
    edges::SparseMatrixCSC{Bool,Int64}
    S::Vector{ST}
    function UnipartiteNetwork{Bool, ST}(edges::M, S::Vector{ST}) where {M<:SparseMatrixCSC, ST}
        check_unipartiteness(edges, S)
        dropzeros!(edges)
        new{Bool,ST}(edges, S)
    end
end

function UnipartiteNetwork(A::M, S::Union{Vector{TT},Nothing}=nothing) where {M <: AbstractMatrix{Bool}, TT}
    if isnothing(S)
        S = "s".*string.(1:size(A, 1))
    else
        _check_species_validity(TT)
    end
    allunique(S) || throw(ArgumentError("All species must be unique"))
    isequal(length(S))(size(A,1)) || throw(ArgumentError("The matrix has the wrong number of top-level species"))
    isequal(length(S))(size(A,2)) || throw(ArgumentError("The matrix has the wrong number of bottom-level species"))
    return UnipartiteNetwork{Bool,eltype(S)}(sparse(A), S)
end

"""
A bipartite probabilistic network is a matrix of floating point numbers, all of
which must be between 0 and 1.
"""
mutable struct BipartiteProbabilisticNetwork{IT <: AbstractFloat, ST} <: AbstractBipartiteNetwork
    edges::SparseMatrixCSC{IT}
    T::Vector{ST}
    B::Vector{ST}
    function BipartiteProbabilisticNetwork(edges, T, B)
        dropzeros!(edges)
        allunique(T) || throw(ArgumentError("All top-level species must be unique"))
        allunique(B) || throw(ArgumentError("All bottom-level species must be unique"))
        allunique(vcat(B,T)) || throw(ArgumentError("Bipartite networks cannot share species across levels"))
        check_probability_values(edges)
        _check_species_validity(eltype(T))
        _check_species_validity(eltype(B))
        check_bipartiteness(edges, T, B)
        new{eltype(edges),eltype(T)}(edges, T, B)
    end
    function BipartiteProbabilisticNetwork{IT,ST}(edges::SparseMatrixCSC{IT}, T::Vector{ST}, B::Vector{ST}) where {IT <: Real, ST}
        return BipartiteProbabilisticNetwork(edges, T, B)
    end
end

function BipartiteProbabilisticNetwork(A::Array{IT,2}, T::Union{Vector{TT},Nothing}=nothing, B::Union{Vector{TT},Nothing}=nothing) where {IT <: AbstractFloat, TT}
    isnothing(B) ? (B = "b".*string.(1:size(A, 2))) : _check_species_validity(TT)
    isnothing(T) ? (T = "t".*string.(1:size(A, 1))) : _check_species_validity(TT)
    isequal(length(T))(size(A,1)) || throw(ArgumentError("The matrix has the wrong number of top-level species"))
    isequal(length(B))(size(A,2)) || throw(ArgumentError("The matrix has the wrong number of bottom-level species"))
    return BipartiteProbabilisticNetwork(sparse(A), T, B)
end

"""
A bipartite quantitative network is matrix of numbers. It is assumed that the
interaction strength are *positive*.
"""
mutable struct BipartiteQuantitativeNetwork{IT <: Number, ST} <: AbstractBipartiteNetwork
    edges::SparseMatrixCSC{IT}
    T::Vector{ST}
    B::Vector{ST}
    function BipartiteQuantitativeNetwork(edges, T, B)
        dropzeros!(edges)
        allunique(T) || throw(ArgumentError("All top-level species must be unique"))
        allunique(B) || throw(ArgumentError("All bottom-level species must be unique"))
        allunique(vcat(B,T)) || throw(ArgumentError("Bipartite networks cannot share species across levels"))
        _check_species_validity(eltype(T))
        _check_species_validity(eltype(B))
        check_bipartiteness(edges, T, B)
        new{eltype(edges),eltype(T)}(edges, T, B)
    end
    function BipartiteQuantitativeNetwork{IT,ST}(edges::SparseMatrixCSC{IT}, T::Vector{ST}, B::Vector{ST}) where {IT <: Real, ST}
        return BipartiteQuantitativeNetwork(edges, T, B)
    end
end

function BipartiteQuantitativeNetwork(A::Array{IT,2}, T::Union{Vector{TT},Nothing}=nothing, B::Union{Vector{TT},Nothing}=nothing) where {IT <: Number, TT}
    isnothing(B) ? (B = "b".*string.(1:size(A, 2))) : _check_species_validity(TT)
    isnothing(T) ? (T = "t".*string.(1:size(A, 1))) : _check_species_validity(TT)
    isequal(length(T))(size(A,1)) || throw(ArgumentError("The matrix has the wrong number of top-level species"))
    isequal(length(B))(size(A,2)) || throw(ArgumentError("The matrix has the wrong number of bottom-level species"))
    return BipartiteQuantitativeNetwork(sparse(A), T, B)
end

"""
A unipartite probabilistic network is a square matrix of floating point numbers,
all of which must be between 0 and 1.
"""
mutable struct UnipartiteProbabilisticNetwork{IT <: AbstractFloat, ST} <: AbstractUnipartiteNetwork
    edges::SparseMatrixCSC{IT}
    S::Vector{ST}
    function UnipartiteProbabilisticNetwork(edges, S)
        dropzeros!(edges)
        allunique(S) || throw(ArgumentError("All species must be unique"))
        check_probability_values(edges)
        _check_species_validity(eltype(S))
        check_unipartiteness(edges, S)
        new{eltype(edges),eltype(S)}(edges, S)
    end
    function UnipartiteProbabilisticNetwork{IT,ST}(edges::SparseMatrixCSC{IT}, S::Vector{ST}) where {IT <: Real, ST}
        return UnipartiteProbabilisticNetwork(edges, S)
    end
end

function UnipartiteProbabilisticNetwork(A::Array{IT,2}, S::Union{Vector{TT},Nothing}=nothing) where {IT <: AbstractFloat, TT}
    isnothing(S) ? (S = "s".*string.(1:size(A, 2))) : _check_species_validity(TT)
    isequal(length(S))(size(A,1)) || throw(ArgumentError("The matrix has the wrong number of top-level species"))
    isequal(length(S))(size(A,2)) || throw(ArgumentError("The matrix has the wrong number of bottom-level species"))
    return UnipartiteProbabilisticNetwork(sparse(A), S)
end

"""
A unipartite quantitative network is a square matrix of numbers.
"""
mutable struct UnipartiteQuantitativeNetwork{IT <: Number, ST} <: AbstractUnipartiteNetwork
    edges::SparseMatrixCSC{IT}
    S::Vector{ST}
    function UnipartiteQuantitativeNetwork(edges, S)
        dropzeros!(edges)
        allunique(S) || throw(ArgumentError("All species must be unique"))
        _check_species_validity(eltype(S))
        check_unipartiteness(edges, S)
        new{eltype(edges),eltype(S)}(edges, S)
    end
    function UnipartiteQuantitativeNetwork{IT,ST}(edges::SparseMatrixCSC{IT}, S::Vector{ST}) where {IT <: Number, ST}
        return UnipartiteQuantitativeNetwork(edges, S)
    end
end

function UnipartiteQuantitativeNetwork(A::Array{IT,2}, S::Union{Vector{TT},Nothing}=nothing) where {IT <: Number, TT}
    isnothing(S) ? (S = "s".*string.(1:size(A, 2))) : _check_species_validity(TT)
    isequal(length(S))(size(A,1)) || throw(ArgumentError("The matrix has the wrong number of top-level species"))
    isequal(length(S))(size(A,2)) || throw(ArgumentError("The matrix has the wrong number of bottom-level species"))
    return UnipartiteQuantitativeNetwork(sparse(A), S)
end

"""
This is a union type for both Bipartite and Unipartite probabilistic networks.
Probabilistic networks are represented as arrays of floating point values ∈
[0;1].
"""
ProbabilisticNetwork = Union{BipartiteProbabilisticNetwork, UnipartiteProbabilisticNetwork}

"""
This is a union type for both Bipartite and Unipartite deterministic networks.
All networks from these class have adjacency matrices represented as arrays of
Boolean values.
"""
BinaryNetwork = Union{BipartiteNetwork, UnipartiteNetwork}

"""
This is a union type for both unipartite and bipartite quantitative networks.
All networks of this type have adjancency matrices as two-dimensional arrays of
numbers.
"""
QuantitativeNetwork = Union{BipartiteQuantitativeNetwork, UnipartiteQuantitativeNetwork}

"""
All non-probabilistic networks
"""
DeterministicNetwork = Union{BinaryNetwork, QuantitativeNetwork}
