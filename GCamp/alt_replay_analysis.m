function [num_activations, pvals ] = alt_replay_analysis(working_dir, min_length_replay )
%UNTITLED2 Summary of this function goes here
%   Gets  all times when the mouse is within the designated sections.

% To-do:
% 1) shuffle data a bunch and get distribution of number of cells active in
% valid sequences by chance
% 2) Compare across sessions
% keyboard

close all

global GROUPED_FLAG

%% Magic Variables - will want to make these as few as possible in the future!

SR = 20; % sample rate in fps
lap_length = 144; % Used in various areas
num_trials = 40; % this will probably need to be fixed somehow or automatically counted in Will's script...
% bonehead way is to increment num_trials up until you reach an error...
vel_thresh = 7; % NOT CURRENTLY USED - threshold in cm/s below which we consider the mouse not moving/not encoding placefields
sig_level = 0.05; % p-value threshold, below which you include fields in the analysis
frame_threshold = 2; % Any neurons who fire after this threshold from the frame in question will not be considered in a sequence
dist_threshold = lap_length/4; % distance threshold (cm) - any cells in a potential sequence that are farther apart than this will not be considered
min_length_default = 3; % Minimum number of cells involved in a replay to be considered valid

%% Part 0: Hardcoded file locations for original writing of function
working_dir_hardcode =  'J:\GCamp Mice\Working\alternation\11_6_2014\Working';
% 'J:\GCamp Mice\Working\alternation\11_13_2014\Working\take2'; %NORVAL % 
% 'C:\Users\Nat\Documents\BU\Imaging\Working\GCamp Mice\G30\alternation\11_13_2014\Working'; % laptop

if ~exist('working_dir','var')
    working_dir = working_dir_hardcode;
end

if ~exist('min_length_replay')
    min_length_replay = min_length_default;
end
 
% pos_file = [working_dir '\pos_corr_to_std.mat'];
place_file = [working_dir '\PlaceMaps.mat'];
pf_stats_file = [working_dir '\PFstats.mat'];

% load(pos_file)
load(place_file)
load(pf_stats_file)

% keyboard
%% Part 1: get timestamps for when mouse is in choice or base, and separate
% into left and right trials (and maybe correct/incorrect)
trial_type = [1 2]; % [left right]
trial_type_text = {'Left Trials' 'Right Trials'};
corr_trial = [1 0] ; % [correct incorrect]
valid_sections = [1 2 3 10]; % matches sections in 'sections.m' file by Will Mau, except 10 = either goal location
section_names = {'Start' 'Center' 'Choice' 'Left Approach' 'Left' 'Left Return' ...
    'Right Approach' 'Right' 'Right Return' 'Goal'};

% Get relevant sections, bounds of those sections, and frames when the
% mouse is in those sections
cd(working_dir)
if ~isempty(GROUPED_FLAG) && GROUPED_FLAG == 1
    pos_data = postrials(x, y, 0, 'skip_rot_check', 1);
else
    pos_data = postrials(x, y, 0, 'skip_rot_check', 0);
end
bounds = sections(x, y, 1 );
[sect, goal] = getsection(x, y,'skip_rot_check',1);

% Get mouse velocity - use isrunning here
% vel = sqrt(diff(pos_align.x).^2+diff(pos_align.y).^2)/...
%     (pos_align.time_interp(2)-pos_align.time_interp(1));
% vel = [0 vel]; % Make this the same length as position data by saying the mouse's
% % velocity at the first frame is 0.
%%
disp('Getting epochs within specified zones')
figure(11)
plot(x,y,'b')
for i = 1:length(trial_type)
    for j = 1:length(valid_sections)
        if valid_sections(j) <= 9 % Filter out only times he is in the specified section
            sect_filter = sect(:,2) == valid_sections(j);
        elseif valid_sections(j) == 10 % Filter out only the times he is in the goal location
            sect_filter = (goal(:,2) == 1 | goal(:,2) == 2);
        end
        sect_and_thresh{i,valid_sections(j)} = ~isrunning & ...
            (sect_filter)' & (pos_data.choice == i) ...
            & (pos_data.alt == 1);
        % put something here to capture frames when the mouse is stopped in a specific area...
        % look at distance of placefield activation from the mouse, and if they
        % are in front of or behind the mouse...need to set up something that
        % identifies areas as illegal, in front, or in back!  or at choie,
        % correct choice or incorrect choice... start simple with just
        % illegal/in front/in back
        
        % Plot to make sure everything above is working correctly (all points in
        % section in yellow stars, below the speed threshold in red circles).
        hold on
        plot(x(sect_filter), y(sect_filter),...
            'y*',x(sect_and_thresh{i,valid_sections(j)}), y(sect_and_thresh{i,valid_sections(j)}),'ro')
        hold off
    end
end

% Define forward, backward, and illegal paths for each section
arms(1).forward = 2;
arms(1).illegal = [6 9];
% arms(1).back = [6 9]; % could be either actually depending on trial type.  Will need to revise.
arms(3).forward = [5 8];
arms(3).illegal = 2;
% arms(3).back = 2;

%% Step 1.5) Parse out times below threshold into epochs...
for i = 1:length(trial_type)
    for j = 1:length(valid_sections)
        n = 1;
        ind_use = find(sect_and_thresh{i, valid_sections(j)});
        clear epoch
        for k = 1:length(ind_use)-1; % Set start of first epoch as first valid frame
            if k == 1
                epoch(n).start = ind_use(k);
                n = n+1;
            elseif ind_use(k-1) ~= ind_use(k) - 1 % assign beginning and ends of epochs
                epoch(n).start = ind_use(k);
                epoch(n-1).end = ind_use(k-1);
                n = n+1;
            elseif k == length(ind_use) - 1 % Set end of last epoch as last valid frame
                epoch(n-1).end = ind_use(k+1);
            end
        end
        
        % Fill in epoch if k is empty
        if isempty(k)
            epoch(1).start = [];
            epoch(1).end = [];
        end
        
        if i == 1
            section(valid_sections(j)).epoch_left = epoch; % assign epochs to section variable
        elseif i == 2
            section(valid_sections(j)).epoch_right = epoch; % assign epochs to section variable
        end
    end
end

%% Step 2: Get locations of centers of mass of all placefields (convert from
% TMap coordinates to centimeters...) and spit these out for each epoch a
% mouse is in a given area (next step is to look at order of firing to see
% if they acutally follow a trajectory!)

% Get span of x and y points
Xcm_span = max(x(:))-min(x(:));
Ycm_span = max(y(:))-min(y(:));
Xcm_min = min(x(:));
Ycm_min = min(y(:));

% Get size of grid used to calculated placemaps
[xgrid_size, ygrid_size] = size(TMap{1});

% Get scale value to convert TMap values to centimeters. Use
% Tmap_value*scale + xmin or ymin value
scale1 = Xcm_span/xgrid_size;
scale2 = Ycm_span/ygrid_size;
scale_use = mean([scale1 scale2]);

% Get centroids of TMap
[Tcentroid, TPixelList, TPixelList_all] = TMap_centroid(TMap);

% Convert centroids to mouse position coordinates
Tcent_cm(:,1) = Tcentroid(:,2)*scale_use + Xcm_min;
Tcent_cm(:,2) = Tcentroid(:,1)*scale_use + Ycm_min;

% Get placefields that have significant p-values
sig_fields = find(pval > (1-sig_level));

%% Step 2a: Check to see if placefield mapping is ok
% figure(56); 
% for tt = 1:length(sig_fields)
%     uu = sig_fields(tt);
%     subplot(2,1,1);
%     plot(x,y,'b',Tcent_cm(uu,1),Tcent_cm(uu,2),'r*'); % Plot trajectory with centroid of firing field on top
%     hold on;
%     plot(bounds.left.x,bounds.left.y, 'r*', bounds.right.x, bounds.right.y, 'b.', bounds.return_l.x, bounds.return_l.y, 'k.',...
%     bounds.return_r.x, bounds.return_r.y, 'k.', bounds.choice.x, bounds.choice.y, 'g.', bounds.center.x, bounds.center.y, 'm.',...
%     bounds.base.x, bounds.base.y, 'g*', bounds.approach_l.x, bounds.approach_l.y, 'b.', bounds.approach_r.x, bounds.approach_r.y, 'k*'); 
%     hold off
%     subplot(2,1,2);
%     imagesc(rot90(TMap{uu},1)); % Plot TMap
%     
%     waitforbuttonpress
% end

% keyboard
%% Step 3: Get average heat map and place-field centroids for cell 
% activations in each region of interest
disp('Getting heatmaps for everything and plotting stuff')
% Initialize data structure
activations = struct('AllTMap',[],'AllTMap_bin',[],'AllTMap_bin_out',[],'AllTcent_cm',[],...
    'n_frames',[],'AllTMap_nan',[],'AllTMap_bin_nan',[],'AllTMap_bin_out_nan',[]);
for j = 1:length(valid_sections)
    nn = 1; % Counter for subplot handles
    for i = 1:length(trial_type)
        % Get bounds of section you are looking at so that you can exclude
        % cells who have a PF in that area...
         section_bounds = get_bounds(bounds,valid_sections(j),i); % Won't work yet for goal locations...
         if valid_sections(j) == 10 && trial_type(i) == 2 % hack to correctly assign section_bounds for right goal
             section_bounds = get_section_bounds(11,bounds);
         end
         bounds_use.y = (section_bounds.x([1 2 3 4 1])-Xcm_min)/scale_use; % Swap these because TMap and x/y are currently set differently...
         bounds_use.x = (section_bounds.y([1 2 3 4 1])-Ycm_min)/scale_use;
        
        % Get placefield information for all epochs in the section of interest
        % Not working correctly for goal locations currently - see lots of
        % activations in the goal box!!! WTF!?!
        if i == 1
            temp = centroid_from_epochs(section(valid_sections(j)).epoch_left,...
                FT, TMap, Tcent_cm,'exclude',bounds_use,TPixelList_all);
        elseif i == 2
            temp = centroid_from_epochs(section(valid_sections(j)).epoch_right,...
                FT, TMap, Tcent_cm,'exclude',bounds_use,TPixelList_all);
        end
        % put NaNs in places of zero occupancy for plotting purposes!
        [ ~, TMap_nan ] = make_nan_TMap( OccMap, temp.AllTMap );
        temp.AllTMap_nan = TMap_nan;
        [ ~, TMap_bin_nan ] = make_nan_TMap( OccMap, temp.AllTMap_bin );
        temp.AllTMap_bin_nan = TMap_bin_nan;
        [ ~, TMap_bin_out_nan ] = make_nan_TMap( OccMap, temp.AllTMap_bin_out );
        temp.AllTMap_bin_out_nan = TMap_bin_out_nan;
        
        if j ~= 1 % Hack to get data structure assignments to work!
            activations(valid_sections(j),i) = activations(1);
        end
        activations(valid_sections(j),i) = temp; % Assign to activations data structure
        
        % Plot summed heatmap out for each section
        figure(20+j)
        h(nn) = subplot(2,1,i);  nn = nn + 1;
        imagesc_nan(rot90(TMap_bin_out_nan/temp.n_frames,1)); colorbar; colormap jet;
        clims(i,:) = get(gca,'CLim');
        title(['Sum of Heatmaps for Non-Running Epochs in ' ...
            section_names{valid_sections(j)} ' Section - ' trial_type_text{i}]);
        hold on;
        bounds_use = get_bounds(bounds,valid_sections(j),i*-1+3); % Grab appropriate bounds for section - note hack to switch bounds for goal boxes - stupid MATLAB!
        plot((bounds_use.x([1 2 3 4 1])-Xcm_min)/scale_use, ...
            (bounds_use.y([1 2 4 3 1])-Ycm_min)/scale_use,'r--') % Plot bounds boxes
        
        
        %     colorbar
        %     subplot(2,1,2)
        %     imagesc_nan(rot90(TMap_bin_nan,1));
        %     title(['Sum of Binary Heatmaps for Non-Running Epochs in ' ...
        %         section_names{valid_sections(j)} ' Section']);
        %     colorbar
    end
    % Get min and max CLIM values for each subplot and make them the same
    % for each subplot...
    clim_min = min(clims(:,1)); clim_max = max(clims(:,2));
    for k = 1: length(h)
    set(h(k),'CLim',[0,clim_max]);
    end
end
    

%% Get L-R plots
for j = 1:length(valid_sections)
    figure(30+j); 
    left = activations(valid_sections(j),1);
    right = activations(valid_sections(j),2);
    LRdiff = left.AllTMap_bin_out_nan/left.n_frames...
        - right.AllTMap_bin_out_nan/right.n_frames;
    imagesc_nan(rot90(LRdiff,1)); % Plot and rotate
    % Set CLim to be equal
    clims2 = get(gca,'CLim');
    clim_eq = max(abs(clims2));
    set(gca,'CLim',[-clim_eq clim_eq]);
    colormap jet;
    colorbar('Ticks',[-clim_eq 0 clim_eq],'TickLabels', {'R > L' 'L = R' 'L > R'});
    title(['Sum of Heatmaps for Non-Running Epochs in ' ...
        section_names{valid_sections(j)} ' Section: L-R trials']);
    hold on;
    bounds_use = get_bounds(bounds,valid_sections(j),1); % Grab appropriate bounds for section
    plot((bounds_use.x([1 2 3 4 1])-Xcm_min)/scale_use, ...
        (bounds_use.y([1 2 4 3 1])-Ycm_min)/scale_use,'r--') % Plot bounds boxes
end

% keyboard
%% Plot activations in order by epoch
% 
% epoch_use = section(10).epoch_right;
% figure(50)
% for m = 1:length(epoch_use)
%     frames_use = epoch_use(m).start:epoch_use(m).end;
%     [ ~, ~, TMap_order ] = get_activation_order(frames_use, FT, TMap);
%     [~, TMap_order_nan ] = make_nan_TMap( OccMap, TMap_order );
%     imagesc_nan(rot90(TMap_order_nan,1)); colorbar; colormap jet;
%     title([num2str(m) ' of ' num2str(length(epoch_use))]);
%     
%    waitforbuttonpress
% end
% keyboard
%% Get activation orders in linearized coordinates
skip = 1; % easy way to skip it!

if skip ~= 1
j = 4; i = 2;
if trial_type(i) == 1
    epoch_use = section(valid_sections(j)).epoch_left;
elseif trial_type(i) == 2
    epoch_use = section(valid_sections(j)).epoch_right;
end

section_bounds = get_bounds(bounds,valid_sections(j),i); 
if valid_sections(j) == 10 && trial_type(i) == 2 % hack to correctly assign section_bounds for right goal
    section_bounds = get_section_bounds(11,bounds);
end

cd(working_dir); % Necessary to make sure you don't accidentally load the wrong rotated.mat file
mouse_pos_use = linearize_trajectory(x,y,'skip_rot_check',1,'x_add',...
    [ceil(min(section_bounds.x)) floor(max(section_bounds.x))],'y_add',...
    [ceil(min(section_bounds.y)) floor(max(section_bounds.y))]);

for m = 1:length(epoch_use)
    frames_use = epoch_use(m).start:epoch_use(m).end;
    [ start_array, all_active_cells, TMap_order ] = get_activation_order(...
        frames_use, FT, TMap);
    raster_use_left = [];
    raster_use_right = [];
    for k = 1:size(start_array,2)
        cells_use = all_active_cells(start_array(:,k));
        Tcent_use = Tcent_cm(cells_use,:);
        if ~isempty(Tcent_use)
            lin_pos_use = linearize_trajectory(x,y,'skip_rot_check',1,...
                'x_add',Tcent_use(:,1),'y_add',Tcent_use(:,2),...
                'suppress_output',1);
            raster_use_left = [raster_use_left; k*ones(length(cells_use),1) lin_pos_use(2,:)'];
            raster_use_right = [raster_use_right; k*ones(length(cells_use),1) lin_pos_use(3,:)'];
        end
    end
    figure(100); 
    subplot(2,1,1)
    if ~isempty(raster_use_left)
        frame_max = max(raster_use_left(:,1));
        plot(raster_use_left(:,2),raster_use_left(:,1)/SR,'b.',...
            [mouse_pos_use(2,1) mouse_pos_use(2,1)], [0 frame_max],'r--',...
            [mouse_pos_use(2,2) mouse_pos_use(2,2)], [0 frame_max],'r--',...
            [0 0],[0 frame_max],'g--',[60 60], [0 frame_max], 'g--')
        set(gca,'YLim',[0 frame_max/SR])
        legend('neuron firing','mouse position','mouse position','center begin','center end')
        xlim([-5 150])
        title(['Left Trajectories, epoch ' num2str(m) ' of ' num2str(length(epoch_use))]);
        xlabel('PF centroid position')
        ylabel('Time elapsed (s)')
    end
    subplot(2,1,2)
    if ~isempty(raster_use_right)
        frame_max = max(raster_use_right(:,1));
        plot(raster_use_right(:,2),raster_use_right(:,1)/SR,'b.',...
            [mouse_pos_use(3,1) mouse_pos_use(3,1)], [0 frame_max],'r--',...
            [mouse_pos_use(3,2) mouse_pos_use(3,2)], [0 frame_max],'r--',...
            [0 0],[0 frame_max],'g--',[60 60], [0 frame_max], 'g--')
        set(gca,'YLim',[0 frame_max/SR])
        
        legend('neuron firing','mouse position','mouse position','center begin','center end')
        xlim([-5 150])
        title(['Right Trajectories, epoch ' num2str(m) ' of ' num2str(length(epoch_use))]);
        xlabel('PF centroid position')
        ylabel('Time elapsed (s)')
    end
    
%     subplot(3,1,3)
%     frames_use = epoch_use(m).start:epoch_use(m).end;
%     [ ~, ~, TMap_order ] = get_activation_order(frames_use, FT, TMap);
%     [~, TMap_order_nan ] = make_nan_TMap( OccMap, TMap_order );
%     imagesc_nan(rot90(TMap_order_nan,1)); colorbar; colormap jet;
%     title([num2str(m) ' of ' num2str(length(epoch_use))]);
%     hold on;
%     bounds_use = get_bounds(bounds,valid_sections(j),i*-1+3); % Grab appropriate bounds for section
%     plot((bounds_use.x([1 2 3 4 1])-Xcm_min)/scale_use, ...
%         (bounds_use.y([1 2 4 3 1])-Ycm_min)/scale_use,'r--') % Plot bounds boxes
%     hold off
    
    waitforbuttonpress
end
    
end
%% Next steps - look at this for other areas, as well as for running epochs!!!

% keyboard

%% Start replay analysis - looking for replay sequences
disp('LOOKING FOR REPLAYS')
for i = 1:2
    j = 4; % i = 2;
    if trial_type(i) == 1
        epoch_use = section(valid_sections(j)).epoch_left;
    elseif trial_type(i) == 2
        epoch_use = section(valid_sections(j)).epoch_right;
    end
    
    % Get bounds of section the mouse is in for the given epochs
    section_bounds = get_bounds(bounds,valid_sections(j),i);
    if valid_sections(j) == 10 && trial_type(i) == 2 % hack to correctly assign section_bounds for right goal
        section_bounds = get_section_bounds(11,bounds);
    end
    
    cd(working_dir); % Necessary to make sure you don't accidentally load the wrong rotated.mat file
    mouse_pos_use = linearize_trajectory(x,y,'skip_rot_check',1,'x_add',...
        [ceil(min(section_bounds.x)) floor(max(section_bounds.x))],'y_add',...
        [ceil(min(section_bounds.y)) floor(max(section_bounds.y))]);
    for bb = 1:100 % Shuffling for loop
        for m = 1:length(epoch_use)
            frames_use = epoch_use(m).start:epoch_use(m).end;
            [ start_array, all_active_cells, TMap_order ] = get_activation_order(...
                frames_use, FT, TMap);
            
            if ~isempty(start_array)
                lin_pos_active = linearize_trajectory(x,y,'skip_rot_check',1,...
                    'x_add',Tcent_cm(all_active_cells,1),'y_add',Tcent_cm(all_active_cells,2),...
                    'suppress_output',1);
                lin_pos_active = lin_pos_active(1,:);
                
                % Get all forward replays
                [epoch_use(m).forward_seq_use, epoch_use(m).forward_seq_pos_use] = get_replays(start_array,...
                    lin_pos_active, frame_threshold, dist_threshold, 'forward',...
                    'exclude',mouse_pos_use(1,:),'min_length_replay', min_length_replay);
                % Get all backward replays
                [epoch_use(m).backward_seq_use, epoch_use(m).backward_seq_pos_use] = get_replays(start_array,...
                    lin_pos_active, frame_threshold, dist_threshold, 'backward',...
                    'exclude',mouse_pos_use(1,:),'min_length_replay',min_length_replay);
                epoch_use(m).num_activations = sum(start_array(:));
                epoch_use(m).forward_num_activations_in_seq = sum(cellfun(@(a) length(a),...
                    epoch_use(m).forward_seq_use));
                epoch_use(m).backward_num_activations_in_seq = sum(cellfun(@(a) length(a),...
                    epoch_use(m).backward_seq_use));
                epoch_use(m).start_array = start_array;
                epoch_use(m).all_active_cells = all_active_cells;
                epoch_use(m).Tcent_cm = Tcent_cm;
                
                % shuffle cell activation orders to test if the number of replays we
                % see is greater than chance
                start_array_shuffle = start_array(:,randperm(size(start_array,2)));
                %         start_array_shuffle = start_array(randperm(size(start_array,1)),:);
                %         start_array_shuffle = start_array(randperm(size(start_array,1)),...
                %             randperm(size(start_array,2)));
                % Get all forward shuffled replays
                [epoch_use(m).forward_shuf_seq_use, epoch_use(m).forward_shuf_seq_pos_use] = get_replays(start_array_shuffle,...
                    lin_pos_active, frame_threshold, dist_threshold, 'forward',...
                    'exclude',mouse_pos_use(1,:),'min_length_replay',min_length_replay);
                % Get all backward shuffled replays
                [epoch_use(m).backward_shuf_seq_use, epoch_use(m).backward_shuf_seq_pos_use] = get_replays(start_array_shuffle,...
                    lin_pos_active, frame_threshold, dist_threshold, 'backward',...
                    'exclude',mouse_pos_use(1,:),'min_length_replay',min_length_replay);
                epoch_use(m).forward_shuf_num_activations_in_seq = sum(cellfun(@(a) length(a),...
                    epoch_use(m).forward_shuf_seq_use));
                epoch_use(m).backward_shuf_num_activations_in_seq = sum(cellfun(@(a) length(a),...
                    epoch_use(m).backward_shuf_seq_use));
            else
                lin_pos_active = [];
                epoch_use(m).num_activations = 0;
                epoch_use(m).forward_num_activations_in_seq = 0;
                epoch_use(m).backward_num_activations_in_seq = 0;
                epoch_use(m).forward_shuf_num_activations_in_seq = 0;
                epoch_use(m).backward_shuf_num_activations_in_seq = 0;
            end
            
            %     disp(['Finished epoch ' num2str(m) ' of ' num2str(length(epoch_use))])
        end
        
        forward_num_activations_in_seq_total = arrayfun(@(a) a.forward_num_activations_in_seq, epoch_use);
        backward_num_activations_in_seq_total = arrayfun(@(a) a.backward_num_activations_in_seq, epoch_use);
        
        forward_shuf_num_activations_in_seq_total = arrayfun(@(a) a.forward_shuf_num_activations_in_seq, epoch_use);
        backward_shuf_num_activations_in_seq_total = arrayfun(@(a) a.backward_shuf_num_activations_in_seq, epoch_use);
        
        num_activations_total = arrayfun(@(a) a.num_activations,epoch_use);
        
        fratio = sum(forward_num_activations_in_seq_total(:))/sum(num_activations_total(:));
        bratio = sum(backward_num_activations_in_seq_total(:))/sum(num_activations_total(:));
        fb_ratio = fratio/bratio;
        
        check_matrix = [sum(forward_num_activations_in_seq_total) sum(backward_num_activations_in_seq_total) sum(num_activations_total);...
            sum(forward_shuf_num_activations_in_seq_total) sum(backward_shuf_num_activations_in_seq_total) sum(num_activations_total)];
        
        shuf_valid_forward_seq_activations(i,bb) = sum(forward_shuf_num_activations_in_seq_total);
        shuf_valid_backward_seq_activations(i,bb) = sum(backward_shuf_num_activations_in_seq_total);
        disp(['Finished shuffle ' num2str(bb) ' of 100'])
    end
    num_valid_forward_activations(i) = sum(forward_num_activations_in_seq_total);
    num_valid_backward_activations(i) = sum(backward_num_activations_in_seq_total);
    num_activations_total_array(i) = sum(num_activations_total);
    
end
num_activations.valid_forward = num_valid_forward_activations;
num_activations.valid_backward = num_valid_backward_activations;
num_activations.shuf_valid_forward = shuf_valid_forward_seq_activations;
num_activations.shuf_valid_backward = shuf_valid_backward_seq_activations;
%% Calculate stats for activations in each direction
% number of cells, avg distance between place fields

if 0
forward_length = [];
backward_length = [];
forward_dist = [];
backward_dist = [];
forward_shuf_length = [];
backward_shuf_length = [];
forward_shuf_dist = [];
backward_shuf_dist = [];
for m = 1:length(epoch_use);
    forward_length = [forward_length cellfun(@(a) length(a), epoch_use(m).forward_seq_use)];
    backward_length = [backward_length cellfun(@(a) length(a), epoch_use(m).backward_seq_use)];
    forward_shuf_length = [forward_shuf_length cellfun(@(a) length(a), epoch_use(m).forward_shuf_seq_use)];
    backward_shuf_length = [backward_shuf_length cellfun(@(a) length(a), epoch_use(m).backward_shuf_seq_use)];
    
    % Forward distance traveled
    temp_fd = cellfun(@(a) diff(a), epoch_use(m).forward_seq_pos_use,...
        'UniformOutput',0);
    for k = 1:length(temp_fd)
        forward_dist = [forward_dist temp_fd{k}];
    end
    % Fix negative distances (where mouse crossed from end of lap into
    % center stem) by adding in the length of a lap
    forward_dist(forward_dist < 0) = forward_dist(forward_dist < 0) + lap_length;
    
    % Backward distance traveled
    temp_bd = cellfun(@(a) diff(a), epoch_use(m).backward_seq_pos_use,...
        'UniformOutput',0);
    for ll = 1:length(temp_bd)
        backward_dist = [backward_dist temp_bd{ll}];
    end
    backward_dist(backward_dist > 0) = backward_dist(backward_dist > 0) - lap_length;
    
    %%% SHUFFLED SEQUENCES %%%
    % Forward distance traveled
    temp_shuf_fd = cellfun(@(a) diff(a), epoch_use(m).forward_shuf_seq_pos_use,...
        'UniformOutput',0);
    for k = 1:length(temp_shuf_fd)
        forward_shuf_dist = [forward_shuf_dist temp_shuf_fd{k}];
    end
    % Fix negative distances (where mouse crossed from end of lap into
    % center stem) by adding in the length of a lap
    forward_shuf_dist(forward_shuf_dist < 0) = forward_shuf_dist(forward_shuf_dist < 0) + lap_length;
    
    % Backward distance traveled
    temp_shuf_bd = cellfun(@(a) diff(a), epoch_use(m).backward_shuf_seq_pos_use,...
        'UniformOutput',0);
    for ll = 1:length(temp_shuf_bd)
        backward_shuf_dist = [backward_shuf_dist temp_shuf_bd{ll}];
    end
    backward_shuf_dist(backward_shuf_dist > 0) = backward_shuf_dist(backward_shuf_dist > 0) - lap_length;
    
end

stats2.forward = replay_stats(forward_length, forward_dist);
stats2.backward = replay_stats(backward_length, backward_dist);
stats2.forward_shuf = replay_stats(forward_shuf_length, forward_shuf_dist);
stats2.backward_shuf = replay_stats(backward_shuf_length, backward_shuf_dist);

end

% Get p-values
for i = 1:2
    pforward(i) = sum(shuf_valid_forward_seq_activations(i,:) > num_valid_forward_activations(i))/...
        length(shuf_valid_forward_seq_activations(i,:));
    pbackward(i) = sum(shuf_valid_backward_seq_activations(i,:) > num_valid_backward_activations(i))/...
        length(shuf_valid_backward_seq_activations(i,:));
    ptotal(i) = mean([pforward(i) pbackward(i)]);
end

pvals.pforward = pforward;
pvals.pbackward = pbackward;
pvals.ptotal = ptotal;

%% Keyboard statement if you want to debug/mess around at the end
% keyboard

%% Hack to plot replay output

if 0
proportion_valid = [254/1110+376/1336, 117/827+143/1076, 12/531+84/937, ...
    92/710+85/783, 97/565+42/245]/2;

shuffle_mean_proportion = [253/1110+332/1336, 110/827+116/1076, 27/531+111/937,...
    88/710+103/783, 80/565+30/245]/2;

pvalue =[ 0.28 0.045 0.48 0.6 0.075];

shuffle_err = shuffle_mean_proportion.*[0.1 0.05 0.2 0.2 0.15];

figure
plot(1:5,proportion_valid,'ro',1:5,shuffle_mean_proportion,'bd')
hold on
errorbar(1:5,shuffle_mean_proportion,shuffle_err)
set(gca,'XTick',[1 2 3 4 5]);
xlabel('Session Number')
ylabel('Proportion of Active Cells in a Valid Replay')
title('Replay Analysis')
legend('Data','Shuffled Data')
end

end

