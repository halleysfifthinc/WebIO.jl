module IJuliaExt

using WebIO
using WebIO: WEBIO_NODE_MIME, _IJuliaInit
using IJulia, Sockets

# struct IJuliaConnection <: AbstractConnection
#     comm::IJulia.CommManager.Comm
# end
IJuliaConnection = Connection{IJulia.CommManager.Comm}

function Sockets.send(c::IJuliaConnection, data)
    IJulia.send_comm(connection(c), data)
end

Base.isopen(c::IJuliaConnection) = haskey(IJulia.CommManager.comms, connection(c).id)

WebIO.register_renderable(T::Type, ::Val{:ijulia}) = nothing

function IJulia.CommManager.register_comm(comm::IJulia.CommManager.Comm{:webio_comm}, x)
    conn = IJuliaConnection(comm)
    comm.on_msg = function (msg)
        data = msg.content["data"]
        WebIO.dispatch(conn, data)
    end
end

"""
A "dummy" type that is used to detect whether or not the Jupyter frontend has
the WebIO integration installed correctly.

This works by definining two Base.show methods:
* One for `WEBIO_NODE_MIME` that displays an empty div (which is effectively
  invisible in the browser).
* One for `text/html` which displays an error message and links to
  troubleshooting documentation.

This works since a properly configured Jupyter frontend should have a renderer
installed for `WEBIO_NODE_MIME` that is preferred over `text/html`. If the HTML
content is actually displayed, it means that the WebIO integration is not
correctly installed.
"""

function Base.show(io::IO, m::WEBIO_NODE_MIME, ::_IJuliaInit)
    Base.show(io, m, node(:div))
end

function Base.show(io::IO, m::MIME"text/html", ::_IJuliaInit)
    Base.print(
        io,
        """
        <div style="padding: 1em; background-color: #f8d6da; border: 1px solid #f5c6cb; font-weight: bold;">
        <p>The WebIO Jupyter extension was not detected. See the
        <a href="https://juliagizmos.github.io/WebIO.jl/latest/providers/ijulia/" target="_blank">
            WebIO Jupyter integration documentation
        </a>
        for more information.
        </div>
        """,
    )
end

function main()
    if !IJulia.inited
        # If IJulia has not been initialized and connected to Jupyter itself,
        # then we have no way to display anything in the notebook and no way
        # to set up comms, so this function cannot run. That's OK, because
        # any IJulia kernels will start up with a fresh process and a fresh
        # copy of WebIO and IJulia.
        return
    end

    IJulia.register_jsonmime(WEBIO_NODE_MIME())

    # See comment on _IJuliaInit for what this does
    display(_IJuliaInit())

    return nothing
end

WebIO.setup_provider(::Val{:ijulia}) = main() # calling setup_provider(Val(:ijulia)) will display the setup javascript

function __init__()
    WebIO.setup(:ijulia)
end

end
