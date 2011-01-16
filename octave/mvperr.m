function err = mvperr(patches, hKern, errfun)
  n = numel(patches);
  dim = size(patches{1});

  % TODO: dispatch _mvperr_impl_gauss
  % TODO: normalize in each step

  % Find the albedo
  meanpatch = zeros(dim);
  for k = 1:n
    meanpatch += patches{k};
  endfor
  meanpatch /= n;

  % Find the sum of square error
  err = 0;
  for k = 1:n
    err += sum(((meanpatch - patches{k}).^2)(:));
  endfor

endfunction
