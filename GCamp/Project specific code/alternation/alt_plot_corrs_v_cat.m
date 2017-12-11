function [ ha ] = alt_plot_corrs_v_cat( MDbase, MDreg, varargin )
% ha  = alt_plot_corrs_v_cat( MDbase, MDreg,... )
%   Plots correlations between neurons in MDbase and MDreg broken down by
%   category: stem place cells (PCs), stem non-place cells (NPCs),
%   splitters, non-stem PCs, and non-stem NPCs

sesh = complete_MD(MDbase);
sesh(2) = complete_MD(MDreg);
%% Parse Inputs
ip = inputParser;
ip.addRequired('MDbase',@isstruct);
ip.addRequired('MDreg',@isstruct);
ip.addParameter('PFname', 'Placefields.mat', @ischar);
ip.addParameter('smoothing','gauss',@(a) any(strcmpi(a,{'gauss','unsmoothed'})));
ip.addParameter('pval_thresh',0.05,@(a) a > 0 & a <= 1);
ip.addParameter('ntrans_thresh',5 ,@(a) a >= 0);
ip.addParameter('sigthresh', 3, @(a) a >= 1); % specify minimum number of signicant splitting bins required to be considered a splitter
ip.parse(MDbase,MDreg,varargin{:});

PFname = ip.Results.PFname;
smoothing = ip.Results.smoothing;
pval_thresh = ip.Results.pval_thresh;
ntrans_thresh = ip.Results.ntrans_thresh;
sigthresh = ip.Results.sigthresh;
%% Step 1: register sessions
% Get map and cells the go silent or become active
neuron_map = neuron_map_simple(MDbase, MDreg, 'suppress_output', true);
coactive_bool = ~isnan(neuron_map) & neuron_map ~= 0;

%% Step 2: load tmaps for each & register
[TMap1, TMap2] = register_tmaps(MDbase, MDreg, PFname, smoothing);

%% Step 3: get correlations for all neurons
rhos = cellfun(@(a,b) corr(a(:),b(:),'type','Spearman','rows','complete'),...
    TMap1(coactive_bool),TMap2(coactive_bool));

%% Step 4: Parse cells into splitters (1), stem PCs(2), stem NPCs (3), 
% arm PCs(4) ,and arm NPCs(5), 0 = doesn't pass ntrans threshold

categories = arrayfun(@(a) alt_parse_cell_category(a, pval_thresh, ...
    ntrans_thresh, sigthresh, PFname), sesh, 'UniformOutput', false);

% Dump these into an array for all the validly mapped cells between each
% session
category_array(:,1) = categories{1}(coactive_bool);
category_array(:,2) = categories{2}(neuron_map(coactive_bool));

%% Step 5: Do breakdown plot!
cat_names = {'Splitters','Stem PCs', 'Stem NPCs', 'Arm PCs', 'Arm NPCs'};
position = [230 360 780 430];
good_cells = category_array(:,1) ~= 0;
ha = scatterBox(rhos(good_cells), category_array(good_cells,1),'xLabels',...
    cat_names, 'yLabel', '\rho (Spearman)','position',position,...
    'transparency', 0.6);
title({[mouse_name_title(MDbase.Animal) ': ' num2str(get_time_bw_sessions(MDbase, MDreg)) ... 
    ' day lag'], [mouse_name_title(MDbase.Date) 's' ...
    num2str(MDbase.Session) ' to ' mouse_name_title(MDreg.Date) 's' ...
    num2str(MDreg.Session)]})

%% Step 6: do an ANOVA on all the categories!!!

end

