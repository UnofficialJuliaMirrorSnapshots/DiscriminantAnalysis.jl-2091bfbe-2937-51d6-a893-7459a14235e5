### Data Whitening Functions

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
        return (copy(transpose(W)), detΣ)
    end
end


@inline regularize(x, y, γ) = (1-γ)*x + γ*y


function whiten_data!(X::Matrix{T}, γ::Union{Nothing,T}; dims::Integer, 
                      df::Integer=size(X,dims)-1) where T
    n, p = check_dims(X, dims=dims)
    
    n > p || error("insufficient number of within-class observations to produce a full " *
                   "rank covariance matrix ($(n) observations, $(p) predictors)")
    
    0 ≤ γ ≤ 1 || throw(DomainError(γ, "γ must be in the interval [0,1]"))

    tol = eps(one(T))*p*maximum(X)

    UDVᵀ = svd!(X, full=false)

    D = UDVᵀ.S

    if γ !== nothing && γ ≠ zero(T)
        # Regularize: Σ = VD²Vᵀ ⟹ Σ(γ) = V((1-γ)D² + (γ/p)trace(D²)I)Vᵀ
        broadcast!(σᵢ -> abs2(σᵢ)/df, D, D)  # Convert data singular values to Σ eigenvalues
        broadcast!(regularize, D, D, mean(D), γ)
        detΣ = prod(D)
        broadcast!(√, D, D)
    else
        detΣ = prod(σᵢ -> abs2(σᵢ)/df, D)
        broadcast!(/, D, D, √(df))
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

    return (copy(transpose(Wᵀ)), detΣ)
end


function whiten_cov!(Σ::AbstractMatrix{T}, γ::Union{Nothing,T}=zero(T); 
                     dims::Integer=1) where T
    (p = size(Σ, 1)) == size(Σ, 2) || throw(DimensionMismatch("Σ must be square"))

    0 ≤ γ ≤ 1 || throw(DomainError(γ, "γ must be in the interval [0,1]"))
    
    if γ !== nothing && γ ≠ zero(T)
        regularize!(Σ, γ)
    end

    UᵀU = cholesky!(Σ, Val(false); check=true)
    
    if dims == 1
        U = UᵀU.U
        detΣ = det(U)^2

        return (inv(U), detΣ)
    else
        Uᵀ = UᵀU.L
        detΣ = det(Uᵀ)^2

        return (inv(Uᵀ), detΣ)
    end 
end