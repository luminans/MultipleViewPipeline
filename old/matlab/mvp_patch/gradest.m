function grad_fd = gradest(FUN,X,lb,ub,options,varargin)
% validateFirstDerivatives Helper function that validates first derivatives of
% objective, nonlinear inequality, and nonlinear equality gradients against
% finite differences. The finite-difference calculation is done according to
% options.FinDiffType.
%
% This function assumes that objective and constraint functions, options,
% and flags for finitedifferences have been validated before calling.
% funfcn and confcn must be cell-array outputs of optimfcnchk. lb and ub
% must be vectors of length number of variables. options is a structure
% that must contain non-empty fields: GradObj, GradConstr, TypicalX,
% FinDiffRelStep, DiffMinChange, DiffMaxChange, and ScaleProblem.
% sizes is a structure that must contain the fields:
% - nVar: the number of variables
% - nFun: the number of functions in a system of equations (or
% least-squares problem)
% - mNonlinEq: the number of nonlinear equality constraints
% - mNonlinIneq: the number of nonlinear inequality constraints
% - xRows: the number of rows in the user's point
% - xCols: the number of columns in the user's point

%   Copyright 2007-2011 The MathWorks, Inc.
%   $Revision: 1.1.6.3 $  $Date: 2011/06/30 16:50:09 $
[sizes.xRows,sizes.xCols] = size(X);
sizes.nVar = length(X);

[X,l,u,msg] = checkbounds(X(:),lb,ub,sizes.nVar);

optiondefault = struct( ...
    'Algorithm','trust-region-reflective', ...
    'AlwaysHonorConstraints','bounds', ...
    'DerivativeCheck','off', ...
    'Diagnostics','off', ...
    'DiffMaxChange',Inf, ...
    'DiffMinChange',0, ...
    'Display','final', ...
    'FinDiffRelStep', [], ...
    'FinDiffType','forward', ...
    'FunValCheck','off', ...
    'GradConstr','off', ...
    'GradObj','off', ...
    'HessFcn',[], ...
    'Hessian',[], ...
    'HessMult',[], ...
    'HessPattern','sparse(ones(numberOfVariables))', ...
    'InitBarrierParam',0.1, ...
    'InitTrustRegionRadius','sqrt(numberOfVariables)', ...
    'LargeScale','on', ...
    'MaxFunEvals',[], ...
    'MaxIter',[], ...
    'MaxPCGIter','max(1,floor(numberOfVariables/2))', ...
    'MaxProjCGIter','2*(numberOfVariables-numberOfEqualities)', ...
    'MaxSQPIter','10*max(numberOfVariables,numberOfInequalities+numberOfBounds)', ...
    'NoStopIfFlatInfeas','off', ...
    'ObjectiveLimit',-1e20, ...
    'OutputFcn',[], ...
    'PhaseOneTotalScaling','off', ...
    'PlotFcns',[], ...
    'PrecondBandWidth',0, ...
    'RelLineSrchBnd',[], ...
    'RelLineSrchBndDuration',1, ...
    'ScaleProblem','none', ...
    'SubproblemAlgorithm','ldl-factorization', ...
    'TolCon',1e-6, ...
    'TolConSQP',1e-6, ...
    'TolFun',1e-6, ...
    'TolGradCon',1e-6, ...
    'TolPCG',0.1, ...
    'TolProjCG',1e-2, ...
    'TolProjCGAbs',1e-10, ...
    'TolX',[], ...
    'TypicalX','ones(numberOfVariables,1)', ...
    'UseParallel','never' ...
    );

% Get logical list of finite lower and upper bounds
finDiffFlags.hasLBs = isfinite(l);
finDiffFlags.hasUBs = isfinite(u);

% Gather options needed for finitedifferences
% Write checked DiffMaxChange, DiffMinChage, FinDiffType, FinDiffRelStep,
% GradObj and GradConstr options back into struct for later use
options.DiffMinChange = optimget(options,'DiffMinChange',optiondefault,'fast');
options.DiffMaxChange = optimget(options,'DiffMaxChange',optiondefault,'fast');
if options.DiffMinChange >= options.DiffMaxChange
    error(message('optimlib:fmincon:DiffChangesInconsistent', sprintf( '%0.5g', options.DiffMinChange ), sprintf( '%0.5g', options.DiffMaxChange )))
end
% Read in and error check option TypicalX
[typicalx,ME] = getNumericOrStringFieldValue('TypicalX','ones(numberOfVariables,1)', ...
    ones(sizes.nVar,1),'a numeric value',options,optiondefault);
if ~isempty(ME)
    throw(ME)
end
checkoptionsize('TypicalX', size(typicalx), sizes.nVar);
options.TypicalX = typicalx;
options.FinDiffType = optimget(options,'FinDiffType',optiondefault,'fast');
options = validateFinDiffRelStep(sizes.nVar,options,optiondefault);

% Create default structure of flags for finitedifferences:
% This structure will (temporarily) ignore some of the features that are
% algorithm-specific (e.g. scaling and fault-tolerance) and can be turned
% on later for the main algorithm.
finDiffFlags.fwdFinDiff = strcmpi(options.FinDiffType,'forward');
finDiffFlags.scaleObjConstr = false; % No scaling for now
finDiffFlags.chkFunEval = false;     % No fault-tolerance yet
finDiffFlags.chkComplexObj = false;  % No need to check for complex values
finDiffFlags.isGrad = true;          % Scalar objective

nVar = sizes.nVar;

% Component-wise relative difference in gradients checked against this tolerance
tol = 1e-6;

% Second, we will attempt to center the perturbed x0 within the finite
% bounds. Variables without finite bounds will remain at the perturbed x0.
X = shiftInitPtToInterior(nVar,X,lb,ub,Inf);

% Create exceptions for possible failures in evaluating the objective or
% constraint functions
derivCheck = 'DerivativeCheck';
obj_ME = MException('optimlib:validateFirstDerivatives:ObjectiveError', ...
    getString(message('optimlib:validateFirstDerivatives:ObjectiveError',derivCheck)));

% Now, evaluate the user objective and constraint functions at the chosen
% point.
try
    fval = feval(FUN,X,varargin{:});
catch userFcn_ME
    userFcn_ME = addCause(userFcn_ME,obj_ME);
    rethrow(userFcn_ME)
end

grad_fd = zeros(nVar,1);
grad_fd = finitedifferences(X,FUN,[],lb,ub,fval,[],[],1:nVar, ...
    options,sizes,grad_fd,[],[],finDiffFlags,[],varargin{:});