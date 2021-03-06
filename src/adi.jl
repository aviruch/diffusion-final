##############################################
#  ________________________________________  #
# /  DO WHAT THE FUCK YOU WANT TO PUBLIC   \ #
# | LICENSE                                | #
# |                                        | #
# | Version 2, December 2004               | #
# |                                        | #
# | Copyright (C) 2018 Anshul Singhvi      | #
# | <asinghvi17@simons-rock.edu>           | #
# |                                        | #
# | Everyone is permitted to copy and      | #
# | distribute verbatim or modified copies | #
# | of this license document, and changing | #
# | it is allowed as long as the name is   | #
# | changed.                               | #
# |                                        | #
# | DO WHAT THE FUCK YOU WANT TO PUBLIC    | #
# | LICENSE                                | #
# |                                        | #
# | TERMS AND CONDITIONS FOR COPYING,      | #
# | DISTRIBUTION AND MODIFICATION          | #
# |                                        | #
# | 0. You just DO WHAT THE FUCK YOU WANT  | #
# \ TO.                                    / #
#  ----------------------------------------  #
#         \   ^__^                           #
#          \  (oo)\_______                   #
#             (__)\       )\/\               #
#                 ||----w |                  #
#                 ||     ||                  #
##############################################
include.(["h.jl"])

"""
On the Methods of Applications of Boundary Conditions to a 2x2 Matrix in an Explicit Manner (because we do not have Time to Implement an Implicit Method of the Application of such Things)

To apply a boundary condition of the zeroth order, a Dirichlet boundary condition, one need only set the temperature of the offending Block to the proscribed one, thus being it back again into the fold.

To apply a boundary condition of the first order, a Neumann boundary condition, one must calculate the necessary flux into it through the application of a 2Δx⋅αΔt.  Should one have knowledge of such mystic paths, the way is then clear to all.
"""

function getT(x)
    return x.T
end

function getxs(b)
    xs = zeros(length(b))
    for i in 2:length(b)
        xs[i] = b[i].Δx + xs[i-1]
    end
    return xs
end

function getys(b)
    ys = zeros(length(b))
    for i in 2:length(b)
        ys[i] = b[i].Δy + ys[i-1]
    end
    return ys
end

function applyBC!(block, bc)
    if bc.type ∈ (:temp, :flux)
        if bc.type == :temp
            block.T = bc.val
        else
            block.T = block.T - bc.val*(block.Δx+block.Δy)
        end
    end
end

function applyBCS!(v, bcs)
    for i ∈ 1:size(v, 1)
        for j ∈ 1:size(v, 2)
            applyBC!(v[i, j], bcs[i, j])
        end
    end
end

function simulate( # Ladri di dirichlette, Neumann-Diebe
    # DEFAULT ARGS
    bb   ,        # the initial distribution
    tm   ::Real,                             # the max time (time goes from 0 to tm)
    Δt   ::Real,                             # the time step
    bcs  ;      # the 'boundary condition' distribution - defines special behaviour like sink/source, fixed-temp, flux in or out
    # KWARGS
    anim_func = Plots.gif,
    fname::String = "lolnv.gif",
    fps::Int = 30,
    nf::Int = 1
    )

    # determine dimensions...

    nx = size(bb, 2)

    ny = size(bb, 1)

    v = deepcopy(bb)

    xs = 1:nx   # the series of 'x coords'
    ys = 1:ny   # the series of 'y coords'

    xstr = (x -> "X$(x)").(xs) # x coords as strings
    ystr = (x -> "Y$(x)").(ys) # y coords as strings
    ts = (t -> "t=$(string(t)[1:min(end, 4)])").(0:Δt*nf:tm) # timesteps as strings

    # bv = vcat(bb)        # convert the 2d matrix of blocks into a 1d construction.

    # begin x-axis config of implicit matrices - one for x axis, one for y axis (since grid may not be square)

    # define diagonals for implicit, tridiagonal matrices

    dsix = ones(nx-1)*-1
    diix = deepcopy(dsix)
    dmix = ones(nx)*2

    dsiy = ones(ny-1)*-1
    diiy = deepcopy(dsiy)
    dmiy = ones(ny)*2

    Mx = Tridiagonal(dsix, dmix, diix)
    My = Tridiagonal(dsiy, dmiy, diiy)

    # Mx[1, 2]       *= 2
    # Mx[end-1, end] *= 2
    # My[1, 2]       *= 2
    # My[end-1, end] *= 2

    # Unlike in the implicit solver, we will have to define the A-matrix separately each time inside the for loop.  This is because the weights on M will change for every vector, and so it is necessary to make sure it works as intended.

    # Use mapslices to more efficiently map Aand its linear combinations...this may not be posiblefor efficiency's sake, though...must be careful unless defining a 'functional matrix'. Or, nest mapslices() calls.

    # The boundary conditions will be done separately for the explicit method, but I will have to find some way of integrating them into the implicit methid

    # now to define the explicit relations

    dsex = ones(nx-1)
    diex = deepcopy(dsex)
    dmex = ones(nx)*(-2)

    dsey = ones(ny-1)
    diey = deepcopy(dsey)
    dmey = ones(ny)*(-2)

    Cx = Tridiagonal(dsex, dmex, diex)    # the explicit method will function through iterative mapping of the slices of the block matrix..
    Cy = Tridiagonal(dsey, dmey, diey)

    # Cx[1, 2]       *= 2
    # Cx[end-1, end] *= 2
    # Cy[1, 2]       *= 2
    # Cy[end-1, end] *= 2

    function solveImplicitX(b)

        K = map((B -> B.D*Δt/(2*B.Δx^2)), b)

        setT!.(b, ((Mx.*K' + UniformScaling(0.5))\getT.(b)))

        return b

    end

    function solveImplicitY(b)

        K = map((B -> B.D*Δt/(2*B.Δy^2)), b)

        setT!.(b, ((My.*K' + UniformScaling(0.5))\getT.(b)))

        return b

    end

    function solveExplicitX(b)

        K = map((B -> B.D*Δt/(2*B.Δx^2)), b)

        setT!.(b, ((Cx.*K' + UniformScaling(0.5))*getT.(b)))

        return b

    end

    function solveExplicitY(b)

        K = map((B -> B.D*Δt/(2*B.Δy^2)), b)

        setT!.(b, ((Cy.*K' + UniformScaling(0.5))*getT.(b)))

        return b
    end

    counter = 0              # the number of iterations

    numberFrames = 1         # the number of frames currently made.  To work with Julia 1-based indexing, it starts at 1 and goes to end.

    pm = Progress(Int(round(length(0:Δt:tm)/nf)), desc="Animating")   # the progresss bar, to be displayed on the screen

    p = Animation()         # initialize the animation
    for t ∈ 0:Δt:tm

        # pre-apply boundary conditions.

        applyBCS!(v, bcs)

        if counter % 2 == 0
            # do implicit in x, explicit in y
            # do explicit in y first
            By = mapslices(solveExplicitY, v, dims=1)
            # now do implicit x relying on By
            v = permutedims(mapslices(solveImplicitX, permutedims(By), dims=1))
        else
            # do explicit in x, implicit in y
            # do explicit in x first
            Bx = mapslices(solveExplicitX, permutedims(v), dims=1)
            # now do implicit y relying on Bx
            v = mapslices(solveImplicitY, permutedims(Bx), dims=1) # double transpose to retain the shape
        end

        if counter % nf == 0 # then plot, otherwise continue with mainloop

            heatmap(
            xstr,
            ystr,
            getT.(v),                 # since plot recipe is not working at the moment, use getT()
            title = ts[numberFrames],
            xlabel="x",
            ylabel="y",
            fill=true,                 # make sure that the graph is filled, not points.
            clims=(0, 30),             # set limits of colormap.  Only supported by plotlyjs, pyplot, glvisualze and hdf5.  No gr, inspectdr or pgfplots.
            aspect_ratio=1
            )
            frame(p)                   # add the current figure as a Frame to the animation
            next!(pm)                  # increment the progress bar
            numberFrames += 1          # increment the number of frames
        end
        counter = counter + 1          # increment the number of iterations
    end

    anim_func(p, fname, fps=fps)       # save the animation using anim_func at fname with framerate fps

end

nx = 50

ny = 50

bcs = zeros(BoundaryCondition, nx, ny)
for i in 1:nx
    bcs[i, 1]   = BoundaryCondition(10, :temp)
    bcs[i, end] = BoundaryCondition(20, :temp)
end

a = reshape([Block2D(1.0, 1.0, 1.0, 1.0) for u ∈ 1:nx*ny], ny, nx)
setT!.(a, 20.0)
setD!.(a, 0.001)
setΔx!.(a, 0.1)
setΔy!.(a, 0.1)
#
# for i ∈ 1:nx
#     for j ∈ 1:ny
#         a[i, j].T += i
#     end
# end

@time simulate(a, 5000.0, 0.1, bcs, fname="lol2d-nfsyconvωεϕϟ⁉.gif", nf = 10)

# For testing do
anim_func = Plots.gif
fname = "lol2d-nfsyconv.gif"
fps = 30z
nf = 1
bb = deepcopy(a)
tm = 5.0
Δt = 0.1


#  _______________________________________________________________________
#/ \                                                                      \
#\_|            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE              |
#  |                    Version 2, December 2004                         |
#  |                                                                     |
#  | Copyright (C) 2018 Anshul Singhvi <asinghvi17@simons-rock.edu>      |
#  |                                                                     |
#  | Everyone is permitted to copy and distribute verbatim or modified   |
#  | copies of this license document, and changing it is allowed as long |
#  | as the name is changed.                                             |
#  |                                                                     |
#  |            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE              |
#  |   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION   |
#  |                                                                     |
#  |  0. You just DO WHAT THE FUCK YOU WANT TO.                          |
#  |   __________________________________________________________________|_
#   \_/____________________________________________________________________/
