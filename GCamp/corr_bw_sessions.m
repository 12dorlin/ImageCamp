function [ corr_1st_2nd, dist_1st_2nd] = corr_bw_sessions(rate_map1, rate_map2, exclude)
%[corr_1st_2nd] = corr_bw_sessions(rate_map1, rate_map2) 
%   Not a great function - do I even use it anymore?
%   Get correlation between rate maps between two sessions.  
%
%   rate_map1 and
%   rate_map2 are the rate maps (could be place field heat maps, reverse
%   place fields, a population vector of firing rates at a given place like
%   a reward location, etc.).  They are currently set as cells, and must
%   have the same x/y dimensions. 
%
%   exclude is a binary vector of indices you want to exclude from using in
%   your calculation of correlations.

% keyboard 

NumXBins = size(rate_map1,2);
NumYBins = size(rate_map1,1);

if nargin < 3
    include = ones(length(rate_map(:)),1); % Include everything
else
    include = find(~exclude);
    
end

% keyboard

corr_1st_2nd = zeros(size(rate_map1));
for j=1:NumYBins
    for i = 1:NumXBins
        temp = corrcoef(rate_map1{j,i}(include),rate_map2{j,i}(include));
        corr_1st_2nd(j,i) = temp(1,2);
        dist_1st_2nd(j,i) = pdist([rate_map1{j,i}(include) rate_map2{j,i}(include)]');
    end
end


end

