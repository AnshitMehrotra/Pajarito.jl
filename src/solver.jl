#  Copyright 2016, Los Alamos National Laboratory, LANS LLC.
#  This Source Code Form is subject to the terms of the Mozilla Public
#  License, v. 2.0. If a copy of the MPL was not distributed with this
#  file, You can obtain one at http://mozilla.org/MPL/2.0/.

#=========================================================
This file implements the default PajaritoSolver
=========================================================#

export PajaritoSolver

immutable PajaritoSolver <: MathProgBase.AbstractMathProgSolver
    log_level::Int              # Verbosity flag: -1 for no output, 0 for minimal solution information, 1 for basic OA iteration and solve statistics, 2 for cone summary information, 3 for infeasibilities of duals, cuts, and OA solutions
    timeout::Float64            # Time limit for outer approximation algorithm not including initial load (in seconds)
    rel_gap::Float64            # Relative optimality gap termination condition

    mip_solver_drives::Bool     # Let MIP solver manage convergence and conic subproblem calls (to add lazy cuts and heuristic solutions in branch and cut fashion)
    mip_solver::MathProgBase.AbstractMathProgSolver # MIP solver (MILP or MISOCP)
    mip_subopt_solver::MathProgBase.AbstractMathProgSolver # MIP solver for suboptimal solves, with appropriate options (gap or timeout) specified directly
    mip_subopt_count::Int       # (Conic only) Number of times to solve MIP suboptimally with time limit between zero gap solves
    round_mip_sols::Bool        # (Conic only) Round the integer variable values from the MIP solver before passing to the conic subproblems
    pass_mip_sols::Bool         # (Conic only) Give best feasible solutions constructed from conic subproblem solution to MIP

    cont_solver::MathProgBase.AbstractMathProgSolver # Continuous solver (conic or nonlinear)
    solve_relax::Bool           # (Conic only) Solve the continuous conic relaxation to add initial subproblem cuts
    dualize_relax::Bool         # (Conic only) Solve the conic dual of the continuous conic relaxation
    dualize_sub::Bool           # (Conic only) Solve the conic duals of the continuous conic subproblems

    soc_disagg::Bool            # (Conic only) Disaggregate SOC cones in the MIP only
    soc_in_mip::Bool            # (Conic only) Use SOC cones in the MIP outer approximation model (if MIP solver supports MISOCP)
    psd_eig::Bool               # (Conic SDP only) Use SDP eigenvector-derived cuts
    psd_soc::Bool               # (Conic SDP only) Use SDP eigenvector SOC cuts (if MIP solver supports MISOCP; except during MIP-driven solve)
    init_soc_one::Bool          # (Conic only) Start with disaggregated L_1 outer approximation cuts for SOCs (if soc_disagg)
    init_soc_inf::Bool          # (Conic only) Start with disaggregated L_inf outer approximation cuts for SOCs (if soc_disagg)
    init_exp::Bool              # (Conic Exp only) Start with several outer approximation cuts on the exponential cones
    init_psd_lin::Bool          # (Conic SDP only) Use SDP initial linear cuts
    init_psd_soc::Bool          # (Conic SDP only) Use SDP initial SOC cuts (if MIP solver supports MISOCP)

    viol_cuts_only::Bool        # (Conic only) Only add cuts that are violated by the current MIP solution (may be useful for MSD algorithm where many cuts are added)
    prim_cuts_only::Bool        # (Conic only) Do not add subproblem cuts
    prim_cuts_always::Bool      # (Conic only) Add primal cuts at each iteration or in each lazy callback
    prim_cuts_assist::Bool      # (Conic only) Add primal cuts only when integer solutions are repeating

    tol_zero::Float64           # (Conic only) Tolerance for small epsilons as zeros
    tol_prim_infeas::Float64    # (Conic only) Tolerance level for cone outer infeasibilities for primal cut adding functions (must be at least 1e-5)
end


function PajaritoSolver(;
    log_level = 1,
    timeout = Inf,
    rel_gap = 1e-5,

    mip_solver_drives = false,
    mip_solver = MathProgBase.defaultMIPsolver,
    mip_subopt_solver = MathProgBase.defaultMIPsolver,
    mip_subopt_count = 0,
    round_mip_sols = false,
    pass_mip_sols = true,

    cont_solver = MathProgBase.defaultConicsolver,
    solve_relax = true,
    dualize_relax = false,
    dualize_sub = false,

    soc_disagg = true,
    soc_in_mip = false,
    psd_eig = true,
    psd_soc = false,

    init_soc_one = true,
    init_soc_inf = true,
    init_exp = true,
    init_psd_lin = true,
    init_psd_soc = false,

    viol_cuts_only = false,
    prim_cuts_only = false,
    prim_cuts_always = false,
    prim_cuts_assist = true,

    tol_zero = 1e-10,
    tol_prim_infeas = 1e-6,
    )

    PajaritoSolver(log_level, timeout, rel_gap, mip_solver_drives, mip_solver, mip_subopt_solver, mip_subopt_count, round_mip_sols, pass_mip_sols, cont_solver, solve_relax, dualize_relax, dualize_sub, soc_disagg, soc_in_mip, psd_eig, psd_soc, init_soc_one, init_soc_inf, init_exp, init_psd_lin, init_psd_soc, viol_cuts_only, prim_cuts_only, prim_cuts_always, prim_cuts_assist, tol_zero, tol_prim_infeas)
end


# Create Pajarito conic model: can solve with either conic algorithm or nonlinear algorithm wrapped with ConicNonlinearBridge
function MathProgBase.ConicModel(s::PajaritoSolver)
    if applicable(MathProgBase.ConicModel, s.cont_solver)
        return PajaritoConicModel(s.log_level, s.timeout, s.rel_gap, s.mip_solver_drives, s.mip_solver, s.mip_subopt_solver, s.mip_subopt_count, s.round_mip_sols, s.pass_mip_sols, s.cont_solver, s.solve_relax, s.dualize_relax, s.dualize_sub, s.soc_disagg, s.soc_in_mip, s.psd_eig, s.psd_soc, s.init_soc_one, s.init_soc_inf, s.init_exp, s.init_psd_lin, s.init_psd_soc, s.viol_cuts_only, s.prim_cuts_only, s.prim_cuts_always, s.prim_cuts_assist, s.tol_zero, s.tol_prim_infeas)
    elseif applicable(MathProgBase.NonlinearModel, s.cont_solver)
        return MathProgBase.ConicModel(ConicNonlinearBridge.ConicNLPWrapper(nlp_solver=s))
    else
        error("Continuous solver specified is neither a conic solver nor a nonlinear solver recognized by MathProgBase\n")
    end
end


# Create Pajarito nonlinear model: can solve with nonlinear algorithm only
function MathProgBase.NonlinearModel(s::PajaritoSolver)
    if !applicable(MathProgBase.NonlinearModel, s.cont_solver)
        error("Continuous solver specified is not a nonlinear solver recognized by MathProgBase\n")
    end

    # Translate options into old nonlinearmodel.jl fields
    verbose = s.log_level
    algorithm = (s.mip_solver_drives ? "BC" : "OA")
    mip_solver = s.mip_solver
    cont_solver = s.cont_solver
    opt_tolerance = s.rel_gap
    time_limit = s.timeout

    return PajaritoNonlinearModel(verbose, algorithm, mip_solver, cont_solver, opt_tolerance, time_limit)
end


# Create Pajarito linear-quadratic model: can solve with nonlinear algorithm wrapped with NonlinearToLPQPBridge
MathProgBase.LinearQuadraticModel(s::PajaritoSolver) = MathProgBase.NonlinearToLPQPBridge(MathProgBase.NonlinearModel(s))
