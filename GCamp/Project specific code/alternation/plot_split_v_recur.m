function [pco_v_rely, pstaybec_v_rely, pco_v_delta, pstaybec_v_delta, ...
    rely_centers, delta_centers, rely_bin_bool, delta_bin_bool] = ...
    plot_split_v_recur( sesh1, sesh2, varargin)
% [pco_v_rely, pstay_v_rely, pco_v_delta, pstay_v_delta, ...
%     rely_centers, delta_centers, h, rely_bin_bool, delta_bin_bool ] = ...
%       plot_split_v_recur( sesh1, sesh2, ...)
%   Gets and plots cell stability (probability of reactivation/coactivation
%   and probility of maintaining/becoming splitter phenotype) vs. "splittiness" ...
%   ( reliability (1-p) and delta_max). Plots out probabilities versus bin
%   centers for each metric, and boolean of bins to include (must have >
%   bin_num_thresh neurons (parameter, default = 5 neurons))
%   Optional inputs: 
%       h - figure axes 
%       rely_edges - , delta_edges,
%   and plot_flag (default = true)

%% Parse Inputs
ip = inputParser;
ip.addRequired('sesh1',@isstruct);
ip.addRequired('sesh2',@isstruct);
ip.addParameter('h', gobjects(0), @ishandle);
ip.addParameter('plot_flag', true, @islogical);
ip.addParameter('rely_edges', 0:0.025:1, @isnumeric);
ip.addParameter('delta_edges', 0:0.05:1, @isnumeric);
% # bins that must be above chance in delta tuning curve to be considered 
% a splitter
ip.addParameter('sigthresh', 3, @(a) a > 0 && (round(a) == a));
% only include bins with more than this # of neurons
ip.addParameter('bin_num_thresh', 5, @(a) a > 0 && (round(a) == a));
ip.parse(sesh1, sesh2, varargin{:});
h = ip.Results.h;
plot_flag = ip.Results.plot_flag;
rely_edges = ip.Results.rely_edges;
delta_edges = ip.Results.delta_edges;
sigthresh = ip.Results.sigthresh;
bin_num_thresh = ip.Results.bin_num_thresh; 

if isempty(h) && plot_flag
    h = figure;
    h.Position = [2200 60 1080 820];
end

rely_centers = rely_edges(1:end-1) + mean(diff(rely_edges))/2;
delta_centers = delta_edges(1:end-1) + mean(diff(delta_edges))/2;

sesh1 = complete_MD(sesh1); sesh2 = complete_MD(sesh2);

neuron_map = neuron_map_simple(sesh1, sesh2, 'suppress_output', true);
%% 1) Load in deltamax and (1-p) for each splitter in session 1
[ rely_val, delta_max] = parse_splitters(sesh1.Location);

%% 2) Get "stability" of splitters from session 1 to session 2
[categories, cat_nums, ~] = arrayfun(@(a) alt_parse_cell_category(a, ...
    0.05, 5, sigthresh,'Placefields.mat'), cat(1,sesh1,sesh2), ...
    'UniformOutput', false);
[~, ~, ~, coactive_bool, category2] = ...
    get_cat_stability(categories, neuron_map, cat_nums{1});
% Get all cells that either stay or become splitters
become_split_bool = category2 == 1;
%% 3) Bin splittiness and get recurrence probability for each bin

% Bin by reliability value, get coactivation and stay probabilities for
% each bin.
[n_rely, ~, bin] = histcounts(rely_val,rely_edges); 
pco_v_rely = arrayfun(@(a) sum(coactive_bool(bin == a)),1:length(n_rely))...
    ./arrayfun(@(a) sum(bin == a),1:length(n_rely));
% pstay_v_rely = arrayfun(@(a) sum(stay_bool(bin == a)),1:length(n_rely))...
%     ./arrayfun(@(a) sum(bin == a),1:length(n_rely));
pstaybec_v_rely = arrayfun(@(a) sum(become_split_bool(bin == a)),1:length(n_rely))...
    ./arrayfun(@(a) sum(bin == a),1:length(n_rely));
rely_bin_bool = n_rely >= bin_num_thresh; % only include bins with min # neurons

% Bin by delta_max value, get coactivation and stay probabilities for
% each bin.
[n_delta, ~, bin] = histcounts(delta_max,delta_edges); 
pco_v_delta = arrayfun(@(a) sum(coactive_bool(bin == a)),1:length(n_delta))...
    ./arrayfun(@(a) sum(bin == a),1:length(n_delta));
% pstay_v_delta = arrayfun(@(a) sum(stay_bool(bin == a)),1:length(n_delta))...
%     ./arrayfun(@(a) sum(bin == a),1:length(n_delta));
pstaybec_v_delta = arrayfun(@(a) sum(become_split_bool(bin == a)),1:length(n_delta))...
    ./arrayfun(@(a) sum(bin == a),1:length(n_delta));
delta_bin_bool = n_delta >= bin_num_thresh; % only include bins with min # neurons


%% 4) Plot everything

if plot_flag
    subplot(2,2,1)
    scatter(rely_centers(rely_bin_bool), pco_v_rely(rely_bin_bool))
    xlabel('Stem splitter reliability (1-p)');
    ylabel('Reactivation prob');
    
    subplot(2,2,2)
    scatter(rely_centers(rely_bin_bool), pstaybec_v_rely(rely_bin_bool))
    xlabel('Stem splitter reliability (1-p)');
    ylabel('Stay/Become splitter prob.');
    
    subplot(2,2,3)
    scatter(delta_centers(delta_bin_bool), pco_v_delta(delta_bin_bool))
    xlabel('Stem splitter \Delta_{max}');
    ylabel('Reactivation prob');
    
    subplot(2,2,4)
    scatter(delta_centers(delta_bin_bool), pstaybec_v_delta(delta_bin_bool))
    xlabel('Stem splitter \Delta_{max}');
    ylabel('Stay/Become splitter prob.');
end

end

