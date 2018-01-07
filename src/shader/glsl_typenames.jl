#came from GLInfo.jl

const GLSL_COMPATIBLE_NUMBER_TYPES = (GLfloat, GLint, GLuint, GLdouble)
const NATIVE_TYPES = Union{
    StaticArray, GLSL_COMPATIBLE_NUMBER_TYPES...,
    Buffer, GPUArray, Shader, GLProgram
}
isa_gl_struct(x::NATIVE_TYPES) = false


opengl_prefix(T)  = error("Object $T is not a supported uniform element type")
opengl_postfix(T) = error("Object $T is not a supported uniform element type")


opengl_prefix(x::Type{T}) where {T <: Union{FixedPoint, Float32, Float16}} = ""
opengl_prefix(x::Type{T}) where {T <: Float64} = "d"
opengl_prefix(x::Type{Cint}) = "i"
opengl_prefix(x::Type{T}) where {T <: Union{Cuint, UInt8, UInt16}} = "u"

opengl_postfix(x::Type{Float64}) = "dv"
opengl_postfix(x::Type{Float32}) = "fv"
opengl_postfix(x::Type{Cint})    = "iv"
opengl_postfix(x::Type{Cuint})   = "uiv"


#Came from GLUniforms or GLInfo.jl
glsl_typename(x::T) where {T} = glsl_typename(T)
glsl_typename(t::Type{Void})     = "Nothing"
glsl_typename(t::Type{GLfloat})  = "float"
glsl_typename(t::Type{GLdouble}) = "double"
glsl_typename(t::Type{GLuint})   = "uint"
glsl_typename(t::Type{GLint})    = "int"
glsl_typename(t::Type{T}) where {T <: Union{StaticVector, Colorant}} = string(opengl_prefix(eltype(T)), "vec", length(T))
glsl_typename(t::Type{TextureBuffer{T}}) where {T} = string(opengl_prefix(eltype(T)), "samplerBuffer")

function glsl_typename(t::Texture{T, D}) where {T, D}
    str = string(opengl_prefix(eltype(T)), "sampler", D, "D")
    t.texturetype == GL_TEXTURE_2D_ARRAY && (str *= "Array")
    str
end
function glsl_typename(t::Type{T}) where T <: SMatrix
    M, N = size(t)
    string(opengl_prefix(eltype(t)), "mat", M==N ? M : string(M, "x", N))
end
toglsltype_string(x::T) where {T<:Union{Real, StaticArray, Texture, Colorant, TextureBuffer, Void}} = "uniform $(glsl_typename(x))"
#Handle GLSL structs, which need to be addressed via single fields
function toglsltype_string(x::T) where T
    if isa_gl_struct(x)
        string("uniform ", T.name.name)
    else
        error("can't splice $T into an OpenGL shader. Make sure all fields are of a concrete type and isbits(FieldType)-->true")
    end
end
toglsltype_string(t::Union{Buffer{T}, GPUVector{T}}) where {T} = string("in ", glsl_typename(T))
# Gets used to access a
function glsl_variable_access(keystring, t::Texture{T, D}) where {T,D}
    fields = SubString("rgba", 1, length(T))
    if t.texturetype == GL_TEXTURE_BUFFER
        return string("texelFetch(", keystring, "index).", fields, ";")
    end
    return string("getindex(", keystring, "index).", fields, ";")
end
function glsl_variable_access(keystring, ::Union{Real, Buffer, GPUVector, StaticArray, Colorant})
    string(keystring, ";")
end

function glsl_variable_access(keystring, t::Any)
    error("no glsl variable calculation available for : ", keystring, " of type ", typeof(t))
end
