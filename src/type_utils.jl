#: Utils

export conjugate, proxy_objfun, proj_objfun, weighted_prox


# Scaled version of proximable/projectionable functions

struct ScaledProximableFun{T,N}<:ProximableFunction{T,N}
    c::Real
    prox::ProximableFunction{T,N}
end

proxy!(y::AbstractArray{CT,N}, λ::T, g::ScaledProximableFun{CT,N}, x::AbstractArray{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = proxy!(y, λ*g.c, g.prox, x)
project!(y::AbstractArray{CT,N}, ε::T, g::ScaledProximableFun{CT,N}, x::AbstractArray{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = project!(y, g.c/ε, g.prox, x)


# LinearAlgebra

Base.:*(c::T, g::ProximableFunction{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = ScaledProximableFun{CT,N}(c, g)
Base.:*(c::T, g::ScaledProximableFun{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = ScaledProximableFun{CT,N}(c*g.c, g.prox)
Base.:/(g::ProximableFunction{CT,N}, c::T) where {T<:Real,N,CT<:RealOrComplex{T}} = ScaledProximableFun{CT,N}(1/c, g)
Base.:/(g::ScaledProximableFun{CT,N}, c::T) where {T<:Real,N,CT<:RealOrComplex{T}} = ScaledProximableFun{CT,N}(g.c/c, g.prox)


# Conjugation of proximable functions

struct ConjugateProxFun{T,N}<:ProximableFunction{T,N}
    prox::ProximableFunction{T,N}
end

function proxy!(y::AbstractArray{CT,N}, λ::T, g::ConjugateProxFun{CT,N}, x::AbstractArray{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}}
    proxy!(y/λ, 1/λ, g.prox, x)
    x .= y-λ*x
    return x
end

conjugate(g::ProximableFunction{T,N}) where {T,N} = ConjugateProxFun{T,N}(g)
conjugate(g::ConjugateProxFun) = g.g


# Proximable function evaluation

struct ProxyObjFun{T,N}<:DifferentiableFunction{T,N}
    λ::Real
    g::ProximableFunction{T,N}
end

proxy_objfun(λ::T, g::ProximableFunction{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = ProxyObjFun{CT,N}(λ, g)
proxy_objfun(λ::T, g::WeightedProximableFun{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = ProxyObjFun{CT,N}(λ, g)

function funeval!(f::ProxyObjFun{CT,N}, y::AbstractArray{CT,N}; gradient::Union{Nothing,AbstractArray{CT,N}}=nothing, eval::Bool=false) where {T<:Real,N,CT<:RealOrComplex{T}}
    x = proxy(y, f.λ, f.g)
    ~isnothing(gradient) && (gradient .= y-x)
    eval ? (return T(0.5)*norm(x-y)^2+f.λ*f.g(x)) : (return nothing)
end


struct ProjObjFun{T,N}<:DifferentiableFunction{T,N}
    ε::Real
    g::ProximableFunction{T,N}
end

proj_objfun(ε::T, g::ProximableFunction{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = ProjObjFun{CT,N}(ε, g)
proj_objfun(ε::T, g::WeightedProximableFun{CT,N}) where {T<:Real,N,CT<:RealOrComplex{T}} = ProjObjFun{CT,N}(ε, g)

function funeval!(f::ProjObjFun{CT,N}, y::AbstractArray{CT,N}; gradient::Union{Nothing,AbstractArray{CT,N}}=nothing, eval::Bool=false) where {T<:Real,N,CT<:RealOrComplex{T}}
    x = project(y, f.ε, f.g)
    ~isnothing(gradient) && (gradient .= y-x)
    eval ? (return T(0.5)*norm(x-y)^2) : (return nothing)
end


# Minimizable type utils

struct DiffPlusProxFun{T,N}<:MinimizableFunction{T,N}
    diff::DifferentiableFunction{T,N}
    prox::ProximableFunction{T,N}
end

Base.:+(f::DifferentiableFunction{T,N}, g::ProximableFunction{T,N}) where {T,N} = DiffPlusProxFun{T,N}(f, g)
Base.:+(g::ProximableFunction{T,N}, f::DifferentiableFunction{T,N}) where {T,N} = f+g