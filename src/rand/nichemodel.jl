"""
    nichemodel(S::Int64, L::Int64)

Return `UnipartiteNetwork` where resources are assign to consumers according to
niche model for a network of `S` species and `L` links.

> Williams, R. J. and Martinez, N. D. (2000) ‘Simple rules yield complex food
> webs’, Nature, 404(6774), pp. 180–183. doi: 10.1038/35004572.

# Examples
```jldoctest
julia> A = nichemodel(50, 220)
```
See also: `cascademodel`, `mpnmodel`, `nestedhierarchymodel`

"""
function nichemodel(S::Int64, L::Int64)

    L >= S*S && throw(ArgumentError("Number of links L cannot be larger than the richness squared"))
    L <= 0 && throw(ArgumentError("Number of links L must be positive"))

    C = L/(S*S)

    return nichemodel(S, C)

end


"""
    nichemodel(N::T) where {T <: UnipartiteNetwork}

Applied to empirical `UnipartiteNetwork` return its randomized version.

# Examples
```jldoctest
julia> empirical_foodweb = EcologicalNetworks.nz_stream_foodweb()[1]
julia> A = nichemodel(empirical_foodweb)
```

"""
function nichemodel(N::T) where {T <: UnipartiteNetwork}
    return nichemodel(richness(N), connectance(N))
end

"""
    nichemodel(S::Int64, C::Float64)



"""
function nichemodel(S::Int64, C::Float64)

    C >= 0.5 && throw(ArgumentError("The connectance cannot be larger than 0.5"))

    # Beta distribution parameter
    β = 1.0/(2.0*C)-1.0

    # Pre-allocate the network
    A = UnipartiteNetwork(zeros(Bool, (S, S)))

    # Generate body size
    n = sort(rand(Uniform(0.0, 1.0), S))

    # Pre-allocate centroids
    c = zeros(Float64, S)

    # Generate random ranges
    r = n .* rand(Beta(1.0, β), S)

    # Generate random centroids
    for s in 1:S
        c[s] = rand(Uniform(r[s]/2, n[s]))
    end

    # The smallest species has a body size and range of 0
    for small_species_index in findall(x -> x == minimum(n), n)
        n[small_species_index] = 0.0
        r[small_species_index] = 0.0
    end

    for consumer in 1:S
        for resource in 1:S
            if n[resource] < c[consumer] + (r[consumer]/2)
                if n[resource] > c[consumer] - (r[consumer]/2)
                    A[consumer, resource] = true
                end
            end
        end
    end

    # Check for disconnected species?

    return A

end

"""

    nichemodel(parameters::Tuple)

Parameters tuple can also be provided in the form (Species::Int64, Co::Float64)
or (Species::Int64, Int::Int64).

"""
function nichemodel(parameters::Tuple)
    return nichemodel(parameters[1], parameters[2])
end
