# Common Functions

### Dimensionality Checks

function check_dims(X::AbstractMatrix; dims::Integer)
    dims ∈ (1, 2) || throw(ArgumentError("dims should be 1 or 2 (got $dims)"))

    n = size(X, dims)
    p = size(X, dims == 1 ? 2 : 1)

    return (n, p)
end

function check_centroid_dims(M::AbstractMatrix, X::AbstractMatrix; dims::Integer)
    n, p = check_dims(X, dims=dims)
    m, p₂ = check_dims(M, dims=dims)
    
    if p != p₂
        rc = dims == 1 ? "columns" : "rows"
        msg = "the number of $(rc) in centroid matrix M must match the number of $(rc) " *
              "in data matrix X (got $(p₂) and $(p))"

        throw(DimensionMismatch(msg))
    end

    return (n, p, m)
end

function check_centroid_dims(M::AbstractMatrix, π::AbstractVector; dims::Integer)
    m, p = check_dims(M, dims=dims)
    m₂ = length(π)

    if m != m₂
        rc = dims == 1 ? "columns" : "rows"
        msg = "the number of $(rc) in centroid matrix M must match the length of class " *
              "index vector y (got $(m) and $(m₂))"

        throw(DimensionMismatch(msg))
    end

    return (m, p)
end

function check_data_dims(X::AbstractMatrix, y::AbstractVector; dims::Integer)
    n, p = check_dims(X, dims=dims)
    n₂ = length(y)

    if n != n₂
        rc = dims == 1 ? "rows" : "columns"
        msg = "the number of $(rc) in data matrix X must match the length of class index " *
              "vector y (got $(n) and $(n₂))"

        throw(DimensionMismatch(msg))
    end

    return n, p
end

function check_priors(π::AbstractVector{T}) where T
    total = sum(π)

    if !isapprox(total, one(T))
        throw(ArgumentError("class priors vector π must sum to 1 (got $(total))"))
    end

    if any(π .≤ 0)
        throw(DomainError(π, "all class priors πₖ must be positive probabilities"))
    end

    return length(π)
end


### Class Calculations

function class_counts(y::Vector{<:Integer}; m::Integer=maximum(y))
    nₘ = zeros(Int, m)

    for i = 1:length(y)
        yᵢ = y[i]
        1 ≤ yᵢ ≤ m || throw(BoundsError(nₘ, yᵢ))
        nₘ[yᵢ] += 1
    end

    return nₘ
end


"""
    _class_centroids!(M, X, y)

Backend for `class_centroids!` - assumes `dims=1`.
"""
function _class_centroids!(M::AbstractMatrix, X::AbstractMatrix, y::Vector{<:Integer})
    n, p, m = check_centroid_dims(M, X, dims=1)
    check_data_dims(X, y, dims=1)
           
    M .= zero(eltype(M))
    nₘ = zeros(Int, m)  # track counts to ensure an observation for each class
    for i = 1:n
        yᵢ = y[i]
        1 ≤ yᵢ ≤ m || throw(BoundsError(M, (yᵢ, 1)))
        nₘ[yᵢ] += 1
        @inbounds for j = 1:p
            M[yᵢ, j] += X[i, j]
        end
    end

    all(nₘ .≥ 1) || error("must have at least one observation per class")
    broadcast!(/, M, M, nₘ)

    return M
end


"""
    class_centroids!(M, X, y; dims=1)

Overwrites matrix `M` with class centroids from `X` based on class indexes from `y`. Use
`dims=1` for row-based observations and `dims=2` for column-based observations.
"""
function class_centroids!(M::AbstractMatrix, X::AbstractMatrix, y::Vector; dims::Integer=1)
    if dims == 1
        return _class_centroids!(M, X, y)
    else
        check_centroid_dims(M, X, dims=dims)
        check_data_dims(X, y, dims=2)
        _class_centroids!(transpose(M), transpose(X), y)
        return M
    end
end


"""
    _center_classes!(X, M, y)

Backend for `center_classes!` - assumes `dims=1`.
"""
function _center_classes!(X::AbstractMatrix, M::AbstractMatrix, y::Vector{<:Integer})
    n, p, m = check_centroid_dims(M, X, dims=1)
    check_data_dims(X, y, dims=1)
    
    for i = 1:n
        yᵢ = y[i]
        1 ≤ yᵢ ≤ m || throw(BoundsError(M, (yᵢ, 1)))
        @inbounds for j = 1:p
            X[i, j] -= M[yᵢ, j]
        end
    end

    return X
end


"""
    center_classes!(X, M, y)

Overwrites `X` with centered version using centroids from `M` based on class labels `y`. 
Use `dims=1` for row-based observations and `dims=2` for column-based observations. 
"""
function center_classes!(X::AbstractMatrix, M::AbstractMatrix, y::Vector{<:Integer}; 
                         dims::Integer=1)
    if dims == 1
        return _center_classes!(X, M, y)
    else
        check_centroid_dims(M, X, dims=dims)
        check_data_dims(X, y, dims=2)

        _center_classes!(transpose(X), transpose(M), y)

        return X
    end
end


"""
    regularize!(Σ₁, Σ₂, λ)
"""
function regularize!(Σ₁::AbstractMatrix{T}, Σ₂::AbstractMatrix{T}, λ::T) where {T}
    (m = size(Σ₁, 1)) == size(Σ₂, 1) || throw(DimensionMismatch(""))
    (n = size(Σ₁, 2)) == size(Σ₂, 2) || throw(DimensionMismatch(""))

    m == n || throw(DimensionMismatch("matrices Σ₁ and Σ₂ must be square"))

    0 ≤ λ ≤ 1 || throw(DomainError(λ, "λ must be in the interval [0,1]"))

    for ij in eachindex(Σ₁)
        Σ₁[ij] = (1-λ)*Σ₁[ij] + λ*Σ₂[ij]
    end
    
    return Σ₁
end


"""
    regularize!(Σ, γ)

Shrink `Σ` matrix towards the average eigenvalue multiplied by the identity matrix.
"""
function regularize!(Σ::AbstractMatrix{T}, γ::T) where {T}
    (p = size(Σ, 1)) == size(Σ, 2) || throw(DimensionMismatch("Σ must be square"))

    0 ≤ γ ≤ 1 || throw(DomainError(γ, "γ must be in the interval [0,1]"))

    a =  γ*tr(Σ)/p  # Average eigenvalue scaled by γ
    
    broadcast!(*, Σ, Σ, 1 - γ)
    for i = 1:p
        Σ[i, i] += a
    end

    return Σ
end


"""
    whiten_data!(X; dims, df)

Compute a whitening transform matrix for centered data matrix `X`. Use `dims=1` for 
row-based observations and `dims=2` for column-based observations. The `df` parameter 
specifies the effective degrees of freedom.
"""
function whiten_data!(X::Matrix{T}; dims::Integer, df::Integer=size(X,dims)-1) where T
    df > 0 || error("degrees of freedom must be greater than 0")

    n, p = check_dims(X, dims=dims)

    n > p || error("insufficient number of within-class observations to produce a full " *
                   "rank covariance matrix ($(n) observations, $(p) predictors)")

    if dims == 1
        # X = QR ⟹ S = XᵀX = RᵀR
        R = UpperTriangular(qr!(X, Val(false)).R)  
    else
        # Xᵀ = LQ ⟹ S = XXᵀ = LLᵀ = RᵀR
        R = UpperTriangular(transpose(lq!(X).L))  
    end

    broadcast!(/, R, R, √(df))

    detΣ = det(R)^2

    W = try
        inv(R)
    catch err
        if isa(err, LAPACKException) || isa(err, SingularException)
            if err.info ≥ 1
                error("rank deficiency detected (collinearity in predictors)")
            end
        end
        throw(err)
    end

    if dims == 1
        return (W, detΣ)
    else
        return (transpose(W), detΣ)
    end
end


function whiten_data!(X::Matrix{T}, γ::T; dims::Integer, df::Integer=size(X,dims)-1) where T
    n, p = check_dims(X, dims=dims)
    
    n > p || error("insufficient number of within-class observations to produce a full " *
                   "rank covariance matrix ($(n) observations, $(p) predictors)")
    
    0 ≤ γ ≤ 1 || throw(DomainError(γ, "γ must be in the interval [0,1]"))

    tol = eps(one(T))*p*maximum(X)

    UDVᵀ = svd!(X, full=false)

    D = UDVᵀ.S
    broadcast!(σᵢ -> (σᵢ^2)/df, D, D)  # Convert data singular values to Σ eigenvalues

    detΣ = prod(D)

    # Regularize: Σ = VD²Vᵀ ⟹ Σ(γ) = V((1-γ)D² + (γ/p)trace(D²)I)Vᵀ
    if γ ≠ 0
        λ_bar = mean(D)
        broadcast!(λᵢ -> √((1-γ)*λᵢ + γ*λ_bar), D, D)
    else
        broadcast!(√, D, D)
    end

    all(D .> tol) || error("rank deficiency (collinearity) detected with tolerance $(tol)")

    # Whitening matrix
    if dims == 1
        Vᵀ = UDVᵀ.Vt
        Wᵀ = broadcast!(/, Vᵀ, Vᵀ, D)  # in-place diagonal matrix multiply DVᵀ
    else
        U = UDVᵀ.U
        Wᵀ = broadcast!(/, U, U, transpose(D))
    end

    return (transpose(Wᵀ), detΣ)
end


function whiten_cov!(Σ::AbstractMatrix{T}, γ::T=zero(T)) where T
    (p = size(Σ, 1)) == size(Σ, 2) || throw(DimensionMismatch("Σ must be square"))

    0 ≤ γ ≤ 1 || throw(DomainError(γ, "γ must be in the interval [0,1]"))
    
    if γ != 0
        regularize!(Σ, γ)
    end
    
    W = inv(cholesky!(Σ, Val(false); check=true).U)
end

