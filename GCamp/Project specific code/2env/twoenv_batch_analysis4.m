% 2env batch analysis

%% Set-up everything
twoenv_reference;

num_shuffles = 1000;

Mouse(1).sesh.square = G30_square;
Mouse(1).sesh.circle = G30_oct;
Mouse(1).sesh.circ2square = G30_botharenas;
Mouse(1).best_angle.square = G30_square_best_angle;
Mouse(1).best_angle.circle = G30_circle_best_angle;
Mouse(1).best_angle.circ2square = G30_both_best_angle;

Mouse(2).sesh.square = G31_square;
Mouse(2).sesh.circle = G31_oct;
Mouse(2).sesh.circ2square = G31_botharenas;
Mouse(2).best_angle.square = G31_square_best_angle;
Mouse(2).best_angle.circle = G31_circle_best_angle;
Mouse(2).best_angle.circ2square = G31_both_best_angle;

Mouse(3).sesh.square = G45_square;
Mouse(3).sesh.circle = G45_oct;
Mouse(3).sesh.circ2square = G45_botharenas;
Mouse(3).best_angle.square = G45_square_best_angle;
Mouse(3).best_angle.circle = G45_circle_best_angle;
Mouse(3).best_angle.circ2square = G45_both_best_angle;

Mouse(4).sesh.square = G48_square;
Mouse(4).sesh.circle = G48_oct;
Mouse(4).sesh.circ2square = G48_botharenas;
Mouse(4).best_angle.square = G48_square_best_angle;
Mouse(4).best_angle.circle = G48_circle_best_angle;
Mouse(4).best_angle.circ2square = G48_both_best_angle;

days.square = square_days;
days.circle = circle_days;
days.circ2square = all_days;

days_diff.square = 0:6;
days_diff.circle = 0:6;
days_diff.circ2square = [0:5 7];

num_animals = length(Mouse);

animal_names = cell(1,num_animals);
for j = 1:num_animals
    animal_names{j} = Mouse(j).sesh.square(1).Animal;
end
    

%% Run rotation analysis
tic;
sesh_type = {'square', 'circle', 'circ2square'};
disp('Performing best angle rotation analysis')
p = ProgressBar(length(sesh_type)*num_animals);
for j = 1:num_animals
    for k = 1:length(sesh_type)
        circ2square_flag = strcmpi(sesh_type{k},'circ2square');
        [corr_mat, shuffle_mat] = twoenv_best_rot_analysis(Mouse(j).sesh.(sesh_type{k}),...
            Mouse(j).best_angle.(sesh_type{k}), circ2square_flag, num_shuffles);
        Mouse(j).corr_mat.(sesh_type{k}) = corr_mat;
        Mouse(j).shuffle_mat.(sesh_type{k}) = shuffle_mat;
        p.progress;
    end

end
p.stop;
toc;
%% Perform local angle rotation analysis for circ2square

comps.before = [1 2 7 8; 3 4 5 6]';  comps.during = [9 11 ; 10 12]'; comps.after = [13 14; 15 16]';

rot_array = 0; % Always compare local cues aligned 
comp_type = {'before','during','after'};
p = ProgressBar(num_animals*length(comp_type)*2*2);
for j = 1:num_animals
    base_dir = ChangeDirectory_NK(Mouse(j).sesh.circ2square(1),0);
    load(fullfile(base_dir,'batch_session_map_trans.mat')); % load batch_session_map
    for k = 1:length(comp_type)
        comp_seshs = comps.(comp_type{k});
        num_sessions = size(comp_seshs,1);
        Mouse(j).local_comps.(comp_type{k}).corr_mat = cell(size(comp_seshs));
        Mouse(j).local_comps.(comp_type{k}).corr_mean = nan(size(comp_seshs));
        for ll = 1:num_sessions
            session1 = Mouse(j).sesh.circ2square(comp_seshs(ll,1)); % Get square session
            for mm = 1:num_sessions
                session2 = Mouse(j).sesh.circ2square(comp_seshs(mm,2)); % Get circle session
                [corr_mat, ~, shuffle_mat2 ] = corr_rot_analysis( session1, session2,...
                    batch_session_map, rot_array, 'trans', true, 'num_shuffles', num_shuffles );
                Mouse(j).local_comps.(comp_type{k}).corr_mat{ll,mm} = corr_mat;
                Mouse(j).local_comps.(comp_type{k}).corr_mean(ll,mm) = nanmean(corr_mat(:));
                p.progress;
            end
        end
    end
end
p.stop;

%% Assemble into All mouse variable

for k = 1:length(comp_type)
    All.local_comps.(comp_type{k}).corr_mat = [];
    All.local_comps.(comp_type{k}).corr_mean = [];
    for j = 1:num_animals
        All.local_comps.(comp_type{k}).corr_mat = [All.local_comps.(comp_type{k}).corr_mat; cat(1,Mouse(j).local_comps.(comp_type{k}).corr_mat{:})];
        All.local_comps.(comp_type{k}).corr_mean = [All.local_comps.(comp_type{k}).corr_mean; Mouse(j).local_comps.(comp_type{k}).corr_mean(:)];
    end
end

%% Run PV analysis at best angle
dispNK('Running PV analysis at best rotation angle')
p = ProgressBar(num_animals*length(sesh_type));
for j = 1:num_animals
    for k = 1:length(sesh_type)
        base_dir = ChangeDirectory_NK(Mouse(j).sesh.(sesh_type{k})(1),0);
        if strcmpi(sesh_type{k},'circ2square')
            load(fullfile(base_dir,'batch_session_map_trans'))
        else
            load(fullfile(base_dir,'batch_session_map'))
        end
        [PV, PV_corrs] = get_PV_and_corr( Mouse(j).sesh.(sesh_type{k}), ...
            batch_session_map, 'alt_pos_file', arrayfun(@(a) ['Pos_align_rot' num2str(a) '.mat'], ...
            Mouse(j).best_angle.(sesh_type{k}), 'UniformOutput',false),...
            'output_flag',false, 'num_shuffles', num_shuffles);
        Mouse(j).PV.(sesh_type{k}) = PV;
        Mouse(j).PV_corrs.(sesh_type{k}) = PV_corrs;
        p.progress;
    end
end
p.stop;

%% Generate tuning curves via PV analysis

% rough start - might need to exclude and +1 or -1 DIs to validate...also,
% not sure if taking the mean is actually legit - might need to only use
% peak FR for each...
DI = get_discr_ratio(squeeze(max(max(Mouse(1).PV.square(1,:,:,:),[],2),[],3)),squeeze(max(max(Mouse(1).PV.square(2,:,:,:),[],2),[],3)));
DI2 = get_discr_ratio(squeeze(max(max(Mouse(1).PV.square(1,:,:,:),[],2),[],3)),squeeze(max(max(Mouse(1).PV.square(8,:,:,:),[],2),[],3)));
DI3 = get_discr_ratio(squeeze(max(max(Mouse(1).PV.circle(1,:,:,:),[],2),[],3)),squeeze(max(max(Mouse(1).PV.circle(2,:,:,:),[],2),[],3)));
DI4 = get_discr_ratio(squeeze(max(max(Mouse(1).PV.circle(1,:,:,:),[],2),[],3)),squeeze(max(max(Mouse(1).PV.circle(8,:,:,:),[],2),[],3)));
DI5 = get_discr_ratio(squeeze(max(max(Mouse(1).PV.circ2square(2,:,:,:),[],2),[],3)),squeeze(max(max(Mouse(1).PV.circ2square(3,:,:,:),[],2),[],3)));
DI6 = get_discr_ratio(squeeze(max(max(Mouse(1).PV.circ2square(2,:,:,:),[],2),[],3)),squeeze(max(max(Mouse(1).PV.circ2square(15,:,:,:),[],2),[],3)));
figure; subplot(1,3,1); histogram(DI,30); hold on; histogram(DI2,30); legend('DI','DI2')
subplot(1,3,2); histogram(DI3,30); hold on; histogram(DI4,30); legend('DI3','DI4')
subplot(1,3,3); histogram(DI5,30); hold on; histogram(DI6,30); legend('DI5','DI6')

%% Calculate Discrimination Ratios for all cells 
square_sesh = [1 2 7 8 9 12 13 14];
circ_sesh = [3 4 5 6 10 11 15 16];
for ii = 1:num_animals
    Mouse(ii).DI = nan(8,8,size(Mouse(ii).PV.circ2square,4)); % Pre-allocate
    for j = 1:8
        PV_square = squeeze(mean(mean(Mouse(ii).PV.circ2square(square_sesh(j),:,:,:),2),3)); % Activity across all bins in the square
        for k = 1:8
            PV_circle = squeeze(mean(mean(Mouse(ii).PV.circ2square(circ_sesh(k),:,:,:),2),3));
            active_cells = PV_square ~= 0 | PV_circle ~= 0;
            DI_temp = (PV_square(active_cells) - PV_circle(active_cells))...
                ./(PV_square(active_cells) + PV_circle(active_cells));
            Mouse(ii).DI(j,k,active_cells) = DI_temp;
        end
    end
end

% Aggregate num of cells with a high v low discrimination ratio
high_discr_ratio = nan(4,8,8);
low_discr_ratio = nan(4,8,8);
for ii = 1:num_animals
    for j = 1:8
        for k = 1:8
            ttt = squeeze(Mouse(ii).DI(j,k,:)); 
            high_discr_ratio(ii,j,k) = sum(abs(ttt) >= 0.75 & abs(ttt) < 1)...
                /sum(~isnan(ttt) & abs(ttt) ~= 1);
            low_discr_ratio(ii,j,k) = sum(abs(ttt) <= 0.25)/sum(~isnan(ttt));
        end
    end
end
All.DI.high_discr_ratio = high_discr_ratio;
All.DI.low_discr_ratio = low_discr_ratio;

%% Plot out DI histograms for each mouse
for ii = 1:4
    figure
    for j = 1:8
        for k = 1:8
            temp = squeeze(Mouse(ii).DI(j,k,:));
            subplot(8,8,8*(j-1)+k);
            histogram(temp,-0.95:0.05:0.95);
        end;
    end;
    title(['Mouse ' num2str(ii)]);
end
%% Plot out ratios of low DI vs high DI neuron ratios across days
low_temp = squeeze(mean(All.DI.low_discr_ratio,1));
high_temp = squeeze(mean(All.DI.high_discr_ratio,1));
figure
plot(low_temp(logical(eye(8))),'b'); 
hold on; plot(high_temp(logical(eye(8))),'r')
%% Aggregate everything by time and type of comparison
% Pre-allocate
for k = 1:length(sesh_type)
    All.days_v_corr2.(sesh_type{k}) = cell(length(days_diff.(sesh_type{k})),1);
    All.days_v_PVcorr.(sesh_type{k}) = cell(length(days_diff.(sesh_type{k})),1);
end
for j = 1:num_animals
    for k = 1:length(sesh_type)
        days_diff_use = days_diff.(sesh_type{k});
        % Get difference in time between sessions (actual and shuffled
        num_sesh = length(days.(sesh_type{k}));
        time_diff_mat = repmat(days.(sesh_type{k}), num_sesh, 1) - ...
            repmat(days.(sesh_type{k})', 1, num_sesh); % Get time between sessions
        
        corr_mat_temp = cellfun(@nanmean, Mouse(j).corr_mat.(sesh_type{k}));
        shuffle_mat_temp = cellfun(@nanmean, Mouse(j).shuffle_mat.(sesh_type{k}));
        
        valid_comp = ~isnan(corr_mat_temp);
        Mouse(j).days_v_corr.(sesh_type{k}) = [time_diff_mat(valid_comp), ...
            corr_mat_temp(valid_comp)];
        Mouse(j).days_v_shuf.(sesh_type{k}) = [time_diff_mat(valid_comp), ...
            shuffle_mat_temp(valid_comp)];
        Mouse(j).days_v_PVcorr.(sesh_type{k}) = [time_diff_mat(valid_comp),...
            Mouse(j).PV_corrs.(sesh_type{k}).PV_corr_mean(valid_comp)];
        Mouse(j).days_v_PVshuf.(sesh_type{k}) = [time_diff_mat(valid_comp),...
            Mouse(j).PV_corrs.(sesh_type{k}).PV_corr_shuffle_mean(valid_comp)];
            
        % Put everything into a 2 column vector. 1: days between
        % comparison, 2 = mean correlation (Spearman)
        ttt = cell(length(days_diff_use),1);
        uuu = cell(length(days_diff_use),1);
        vvv = uuu;
        www = uuu;
        for ll = 1:length(days_diff_use)
            day_ind = Mouse(j).days_v_corr.(sesh_type{k})(:,1) == days_diff_use(ll);
            ttt{ll} = Mouse(j).days_v_corr.(sesh_type{k})(day_ind,2); 
            uuu{ll} = Mouse(j).days_v_shuf.(sesh_type{k})(day_ind,2);
            vvv{ll} = Mouse(j).days_v_PVcorr.(sesh_type{k})(day_ind,2);
            www{ll} = Mouse(j).days_v_PVshuf.(sesh_type{k})(day_ind,2);
            All.days_v_corr2.(sesh_type{k}){ll} = cat(1,...
                All.days_v_corr2.(sesh_type{k}){ll}, ttt{ll});
            All.days_v_PVcorr.(sesh_type{k}){ll} = cat(1,...
                All.days_v_PVcorr.(sesh_type{k}){ll}, vvv{ll});
        end
        Mouse(j).days_v_corr2.(sesh_type{k}) = cellfun(@mean, ttt);
        Mouse(j).days_v_shuf2.(sesh_type{k}) = cellfun(@mean, uuu);
        Mouse(j).days_v_PVcorr2.(sesh_type{k}) = cellfun(@mean, vvv);
        Mouse(j).days_v_shuf2.(sesh_type{k}) = cellfun(@mean, www);
        
        
    end
end

%% Plot mean correlations vs days for each comparison type
marker_type = {'s', 'o', 'x'};
plot_combined = false;

if plot_combined; figure; end
for k = 1:length(sesh_type)
    if ~plot_combined; figure; end
    days_diff_use = days_diff.(sesh_type{k});
    for j = 1:num_animals
        plot(Mouse(j).days_v_corr.(sesh_type{k})(:,1), ...
            Mouse(j).days_v_corr.(sesh_type{k})(:,2),marker_type{k});
        hold on
%         plot(days_diff,Mouse(j).days_v_corr2.(sesh_type{k}))
%         plot(days_diff,Mouse(j).days_v_shuf2.(sesh_type{k}),'k--')
    end
    for j = 1:num_animals
        plot(Mouse(j).days_v_shuf.(sesh_type{k})(:,1), ...
            Mouse(j).days_v_shuf.(sesh_type{k})(:,2),'k.');
        hold on
    end
    plot(days_diff_use, cellfun(@mean, All.days_v_corr2.(sesh_type{k})),'b-')
    legend(cellfun(@mouse_name_title, animal_names,'UniformOutput',0),'Shuffled')
    xlabel('Days between session'); 
    ylabel('Mean Spearman Correlation b/w TMaps')
    title(sesh_type{k})
    if strcmpi(sesh_type{k},'circ2square')
        xlim([-1 8]); ylim([-0.1 1]);
        set(gca,'XTick',0:7)
    else
        xlim([-1 7]); ylim([-0.1 1]);
        set(gca,'XTick',0:6)
    end
end

%% Plot histograms of the above plots
edges = -0.1:0.025:1;
figure;
for k = 1:length(sesh_type)
    temp = [];
    temp_shuf = [];
    for j = 1:num_animals
        temp = [temp; Mouse(j).days_v_corr.(sesh_type{k})(:,2)];
        temp_shuf = [temp_shuf; Mouse(j).days_v_shuf.(sesh_type{k})(:,2)];
    end
    subplot(3,1,k)
    histogram(temp, edges,'Normalization','probability')
    hold on
%     histogram(temp_shuf(:,2), edges, 'Normalization','probability')
    [f,x] = ecdf(temp_shuf);
    shuf_lim = repmat(x(findclosest(f,0.975)),1,2);
    ylims = get(gca,'YLim');
    plot(shuf_lim, ylims,'r--');
    set(gca,'YLim',ylims);
    hold off
    title([sesh_type{k} ' b/w session correlations'])
    xlabel('Mean Correlation')
    ylabel('Probability')
end

%% Plot mean correlations vs days for each comparison type for PV
marker_type = {'ko', 'ko', 'ko'}; % marker_type = {'s', 'o', 'x'};
plot_combined = false;

if plot_combined; figure; end
for k = 1:length(sesh_type)
    if ~plot_combined; figure; end
    set(gcf,'Position',[488.2000  393.0000  784.8000  368.8000])
    days_diff_use = days_diff.(sesh_type{k});
    for j = 1:num_animals
        hmouse = plot(Mouse(j).days_v_PVcorr.(sesh_type{k})(:,1), ...
            Mouse(j).days_v_PVcorr.(sesh_type{k})(:,2),marker_type{k});
        hmouse.Color = [0.67 0.67 0.67];
        hold on
%         plot(days_diff,Mouse(j).days_v_corr2.(sesh_type{k}))
%         plot(days_diff,Mouse(j).days_v_shuf2.(sesh_type{k}),'k--')
    end
    for j = 1:num_animals
        plot(Mouse(j).days_v_PVshuf.(sesh_type{k})(:,1), ...
            Mouse(j).days_v_PVshuf.(sesh_type{k})(:,2),'k.');
        hold on
    end
    plot(days_diff_use, cellfun(@mean, All.days_v_PVcorr.(sesh_type{k})),'b-')
%     legend(cellfun(@mouse_name_title, animal_names,'UniformOutput',0),'Shuffled')
    xlabel('Days between session'); 
    ylabel('Mean Spearman Correlation b/w PVs')
    title(sesh_type{k})
    if strcmpi(sesh_type{k},'circ2square')
        xlim([-1 8]); ylim([-0.1 0.6]);
        set(gca,'XTick',0:7)
    else
        xlim([-1 7]); ylim([-0.1 0.6]);
        set(gca,'XTick',0:6)
    end
end

%% Alternate Coherency Analysis - Based off of best angle distribution
rot_bins = {0:90:360, 0:15:360, 0:15:360};
alpha = 0.05;
for k = 1:length(sesh_type)
    for j = 1:num_animals
        [~, best_angle_all2, ~, ~, ~, ~, hh] = twoenv_rot_analysis_full(...
            Mouse(j).sesh.(sesh_type{k}), sesh_type{k}, 'num_shuffles' , 1000);  % These should all already be run so this should be fast
%         close(hh); % close only those figures above
        [ chi2stat_mat, p_mat, df ] = calc_coherency( best_angle_all2, ...
            rot_bins{k});
        Mouse(j).coherency.(sesh_type{k}).pmat = p_mat;
        Mouse(j).coherency.(sesh_type{k}).chi2stat = chi2stat_mat;
        Mouse(j).coherency.(sesh_type{k}).df = df;
        
        % Bonferroni correct and aggregate for plotting
        good_comps = ~isnan(p_mat);
        num_comps = sum(good_comps(:));
        hmat = p_mat < alpha/num_comps;
        Mouse(j).coherency.(sesh_type{k}).hmat = hmat;
        All.coherency.(sesh_type{k}).simple(j,1) = sum(hmat(:))/num_comps; % coherent
        All.coherency.(sesh_type{k}).simple(j,2) = 1 - sum(hmat(:))/num_comps;
    end
end

%% Plot results

% Assemble matrices
square_mean = mean(All.coherency.square.simple,1);
circle_mean = mean(All.coherency.circle.simple,1);
circ2square_mean = mean(All.coherency.circ2square.simple,1);

figure(101)
% Plot
h = bar(1:2,[square_mean', circle_mean', circ2square_mean']);
set(gca,'XTickLabel',{'Coherent', 'Global Remapping'} )
legend('Within square', 'Within circle', 'Square to Circle')
xlabel('Remapping Type')
ylabel('Proprotion of Comparisons')

% Now do each mouse
compare_type = {'square','circle','circ2square'};
hold on
for j = 1:length(compare_type)
    plot(repmat(h(j).XData + h(j).XOffset, num_animals,1),...
        All.coherency.(compare_type{j}).simple,'ko')
end
hold off


%% Remapping analysis
alpha = 0.05; % p-value cutoff
align_cutoff = 30; % Angle difference for which the circle is considered aligned, e.g. if you think anything <=15 degrees different should count, set it to 15.
num_cell_thresh = 20; % Exclude any comparisons where the number of cells registered is less than this

% Find global remappers

% Pre-allocate
for k = 1:length(sesh_type)
    All.global_remap_stats.num_sessions.(sesh_type{k}) = ...
        twoenv_squeeze(zeros(size(Mouse(1).corr_mat.(sesh_type{k}))));
end

% Establish is session comparisons are coherent or not
for k = 1:length(sesh_type)
    for j = 1:num_animals
        valid_comp = cellfun(@(a) ~isempty(a), Mouse(j).corr_mat.(sesh_type{k}));
        hks = false(size(valid_comp));
        pks = nan(size(valid_comp));
        num_comps = sum(valid_comp(:)); % Get number of comparisons
        alpha_corr = alpha/num_comps;
        % Run KS test between real and shuffled distributions at best angle
        [hks_temp, pks_temp] = cellfun(@(a,b) kstest2(a,b,'tail','smaller','alpha',alpha_corr),...
            Mouse(j).corr_mat.(sesh_type{k})(valid_comp),...
            Mouse(j).shuffle_mat.(sesh_type{k})(valid_comp));
        hks(valid_comp) = hks_temp;
        pks(valid_comp) = pks_temp;
        hks = twoenv_squeeze(hks);
        pks = twoenv_squeeze(pks);
        Mouse(j).global_remap_stats.(sesh_type{k}).ks.h = hks;
        Mouse(j).global_remap_stats.(sesh_type{k}).ks.p = pks;
        
        % Run shuffled test - compare mean of actual data to mean of each
        % shuffle
        [hshuf, pshuf] = cellfun(@(a,b) twoenv_coh_sig(a,b,alpha_corr), ...
            Mouse(j).corr_mat.(sesh_type{k}), Mouse(j).shuffle_mat.(sesh_type{k}),...
            'UniformOutput',false);
        if strcmpi(sesh_type{k},'circ2square')
            hshuf = twoenv_squeeze(cellfun(@double,hshuf));
            pshuf = twoenv_squeeze(cellfun(@double,pshuf));
        else
            hshuf = cellfun(@double,hshuf);
            pshuf = cellfun(@double,pshuf);
        end
        
        hshuf = ~isnan(hshuf) & hshuf == 1;
        Mouse(j).global_remap_stats.(sesh_type{k}).shuf_test.h_remap = ...
            twoenv_squeeze(hshuf);
        Mouse(j).global_remap_stats.(sesh_type{k}).shuf_test.p_remap = ...
            twoenv_squeeze(pshuf);
        
        % Get number of cells for each comparison and test v threshold
        num_cells = cellfun(@(a) sum(~isnan(a)),...
            twoenv_squeeze(Mouse(j).corr_mat.(sesh_type{k})));
        Mouse(j).global_remap_stats.(sesh_type{k}).num_cells = num_cells;
        
        % Finally, aggregate all together
        % This is not entirely correct - want to exclude any comparisons 
        % with less than the required number of cells - this counts those
        % as global remappers
%         h_coherent = hks & hshuf & (num_cells >= num_cell_thresh); 
        
        % This is better - incorporate cell thresh somewhere below somehow
        h_coherent = hks & hshuf; 
            
        h_mat = double(~h_coherent);
        p_mat = max(cat(3,pks,pshuf),[],3);
        h_mat(logical(twoenv_squeeze(~valid_comp))) = nan;
        p_mat(logical(twoenv_squeeze(~valid_comp))) = nan;
        Mouse(j).global_remap_stats.(sesh_type{k}).h_remap = h_mat;
        Mouse(j).global_remap_stats.(sesh_type{k}).p_remap = p_mat;
        
        All.global_remap_stats.num_sessions.(sesh_type{k}) = ...
            All.global_remap_stats.num_sessions.(sesh_type{k}) + h_mat;
        
    end
end

%%

% Get distal cue v local cue v incongruous comparisons
for k = 1:length(sesh_type)
    num_sessions = length(Mouse(1).sesh.(sesh_type{k}));
%     circ2square_flag = strcmpi('circ2square',sesh_type{k});
    for j = 1:num_animals
        Mouse(j).distal_rot_mat.(sesh_type{k}) = nan(num_sessions,num_sessions);
        angle_diff_mat = twoenv_squeeze(repmat(Mouse(j).best_angle.(sesh_type{k}), num_sessions, 1) - ...
            repmat(Mouse(j).best_angle.(sesh_type{k})', 1, num_sessions));
%         if circ2square_flag; end_ind = num_sessions; else; end_ind = num_sessions-1; end 
        for ll = 1:num_sessions-1 %1:end_ind
            [~, sesh1_rot] = get_rot_from_db(Mouse(j).sesh.(sesh_type{k})(ll));
%             if circ2square_flag; start_ind = 1; else; start_ind = ll+1; end
            for mm = ll+1:num_sessions
                [~, sesh2_rot] = get_rot_from_db(Mouse(j).sesh.(sesh_type{k})(mm));
                distal_rot = sesh2_rot - sesh1_rot;
                if distal_rot < 0
                    distal_rot = distal_rot + 360;
                elseif distal_rot >= 360
                    distal_rot = distal_rot < 360;
                end
                
                Mouse(j).distal_rot_mat.(sesh_type{k})(ll,mm) = distal_rot;
                
                
            end
        end
        valid_comp = logical(twoenv_squeeze(cellfun(@(a) ~isempty(a), Mouse(j).corr_mat.(sesh_type{k}))));
        global_remap = zeros(8, 8);
        global_remap(valid_comp) = Mouse(j).global_remap_stats.(sesh_type{k}).h_remap(valid_comp);
        
        %%% Breakdown with no regard for where comparisons are rotated or
        %%% not
        %  Note that this is super-conservative for designating session
        %  comparisons as tracking local cues - when there is NO
        %  conflict between distal/local cues (e.g. rotation = 0), cells
        %  aligning to distal/local cues are designated as distal
        %  following...
        distal_mat_use = twoenv_squeeze(Mouse(j).distal_rot_mat.(sesh_type{k}));
        distal_align_mat = twoenv_squeeze(double(abs(angle_diff_mat - ...
            distal_mat_use) <= align_cutoff & ~global_remap));
        local_align_mat = twoenv_squeeze(double(abs(angle_diff_mat) ...
            <= align_cutoff & ~global_remap & ...
            abs(angle_diff_mat - distal_mat_use) > align_cutoff));
        other_align_mat = twoenv_squeeze(double(abs(angle_diff_mat) > ...
            align_cutoff & abs(angle_diff_mat - distal_mat_use) ...
            > align_cutoff & ~global_remap));
        global_remap = twoenv_squeeze(double(global_remap));
        
        % Breakdown with regard for rotation of sessions
        rotation_log = ~isnan(distal_mat_use) & distal_mat_use ~= 0; % Identify comparisons with rotation between sessions
        
        % With rotation
        distal_align_mat_r = double(rotation_log & distal_align_mat);
        local_align_mat_r = double(rotation_log & local_align_mat);
        other_align_mat_r = double(rotation_log & other_align_mat);
        global_remap_r = double(rotation_log & global_remap);
        distal_align_mat_r(~valid_comp | ~rotation_log) = nan; local_align_mat_r(~valid_comp | ~rotation_log) = nan;
        other_align_mat_r(~valid_comp | ~rotation_log) = nan; global_remap_r(~valid_comp | ~rotation_log) = nan;
        
        % No rotation
        local_align_mat_nr = double(~rotation_log & local_align_mat) + double(~rotation_log & distal_align_mat);
        other_align_mat_nr = double(~rotation_log & other_align_mat);
        global_remap_nr = double(~rotation_log & global_remap);
        local_align_mat_nr(~valid_comp | rotation_log) = nan;
        other_align_mat_nr(~valid_comp | rotation_log) = nan; global_remap_nr(~valid_comp | rotation_log) = nan;
        
        % Make non-valid comparisons nan for ease of viewing
        distal_align_mat(~valid_comp) = nan; local_align_mat(~valid_comp) = nan;
        other_align_mat(~valid_comp) = nan; global_remap(~valid_comp) = nan;
        
        % Dump everything into mouse structures
        Mouse(j).remapping_type.distal_align.(sesh_type{k}) = distal_align_mat;
        Mouse(j).remapping_type.local_align.(sesh_type{k}) = local_align_mat;
        Mouse(j).remapping_type.other_align.(sesh_type{k}) = other_align_mat;
        Mouse(j).remapping_type.global.(sesh_type{k}) = global_remap;
        
        Mouse(j).remapping_type2.rotation.distal_align.(sesh_type{k}) = distal_align_mat_r;
        Mouse(j).remapping_type2.rotation.local_align.(sesh_type{k}) = local_align_mat_r;
        Mouse(j).remapping_type2.rotation.other_align.(sesh_type{k}) = other_align_mat_r;
        Mouse(j).remapping_type2.rotation.global.(sesh_type{k}) = global_remap_r;
        
        Mouse(j).remapping_type2.no_rotation.distal_align.(sesh_type{k}) = nan(size(local_align_mat_nr));
        Mouse(j).remapping_type2.no_rotation.local_align.(sesh_type{k}) = local_align_mat_nr;
        Mouse(j).remapping_type2.no_rotation.other_align.(sesh_type{k}) = other_align_mat_nr;
        Mouse(j).remapping_type2.no_rotation.global.(sesh_type{k}) = global_remap_nr;
        
    end
end

%% Double check above
align_type = {'distal_align','local_align','other_align','global'};
for k = 1:length(sesh_type)
    for j = 1:num_animals
        temp = nan(size(Mouse(j).remapping_type.distal_align.(sesh_type{k})));
        for ll = 1:length(align_type)
            temp = cat(3, temp, Mouse(j).remapping_type.(align_type{ll}).(sesh_type{k}));
        end
        sum_check.(sesh_type{k})(j,:,:) = nansum(temp,3);
    end
end

%% Aggregate Results and Plot Breakdown of alignment type by mouse and combined
plot_flag = false;

for k = 1:length(sesh_type)
    ratio_plot_all = zeros(num_animals, length(align_type));
    ratio_plot_all2_r = zeros(num_animals, length(align_type));
    ratio_plot_all2_nr = zeros(num_animals, length(align_type));
    for j = 1:num_animals
        if plot_flag; figure(10 + j); end
%         num_comps = sum(sum(cellfun(@(a) ~isempty(a), Mouse(j).corr_mat.(sesh_type{k}))));
        num_comps = sum(~isnan(Mouse(j).remapping_type.local_align.(sesh_type{k})(:)));
        num_comps_r = sum(~isnan(Mouse(j).remapping_type2.rotation.local_align.(sesh_type{k})(:)));
        num_comps_nr = sum(~isnan(Mouse(j).remapping_type2.no_rotation.local_align.(sesh_type{k})(:)));
        ratio_plot = zeros(size(align_type)); ratio_plot2_r = zeros(size(align_type));
        ratio_plot2_nr = zeros(size(align_type));
        for ll = 1:length(align_type)
            ratio_plot(ll) = nansum(Mouse(j).remapping_type.(align_type{ll}).(sesh_type{k})(:))/num_comps;
            ratio_plot_r(ll) = nansum(Mouse(j).remapping_type2.rotation.(align_type{ll}).(sesh_type{k})(:))/num_comps_r;
            ratio_plot_nr(ll) = nansum(Mouse(j).remapping_type2.no_rotation.(align_type{ll}).(sesh_type{k})(:))/num_comps_nr;
        end
        
        ratio_plot_all(j,:) = ratio_plot;
        ratio_plot_all2_r(j,:) = ratio_plot_r;
        ratio_plot_all2_nr(j,:) = ratio_plot_nr;
        if plot_flag
            subplot(length(sesh_type),1,k)
            bar(1:length(align_type), ratio_plot)
            xlim([0 length(align_type) + 1]); ylim([0 1]);
            set(gca,'XTick',1:length(align_type),'XTickLabel',cellfun(@mouse_name_title, align_type,'UniformOutput',0));
            ylabel('Ratio')
            title([mouse_name_title(animal_names{j}) ' - ' sesh_type{k}])
        end
        
    end
    
    All.ratio_plot_all.(sesh_type{k}) = ratio_plot_all;
    All.ratio_plot_all2.rotation.(sesh_type{k}) = ratio_plot_all2_r;
    All.ratio_plot_all2.no_rotation.(sesh_type{k}) = ratio_plot_all2_nr;

    if plot_flag
        figure(10+num_animals+1)
        subplot(length(sesh_type),1,k)
        bar(1:length(align_type), mean(ratio_plot_all,1))
        xlim([0 length(align_type) + 1]); ylim([0 1]);
        set(gca,'XTick',1:length(align_type),'XTickLabel',cellfun(@mouse_name_title, align_type,'UniformOutput',0));
        ylabel('Ratio')
        title(['All Mice - ' sesh_type{k}])
    end
    
end

%% Full Alignment Breakdown Plot - No Rotation Distinction, Coherent v Global only
align_type = {'distal_align','local_align','other_align','global'};
align_text = {'Coherent - Distal Cues', 'Coherent - Local Cues', 'Coherent - Other', 'Global Remapping'};

% Assemble matrices
square_mean = mean(All.ratio_plot_all.square,1);
circle_mean = mean(All.ratio_plot_all.circle,1);
circ2square_mean = mean(All.ratio_plot_all.circ2square,1);

figure(16)
% Plot
h = bar(1:length(align_type),[square_mean', circle_mean', circ2square_mean']);
set(gca,'XTickLabel',cellfun(@mouse_name_title,align_text,'UniformOutput',0))
legend('Within square', 'Within circle', 'Square to Circle')
xlabel('Remapping Type')
ylabel('Proprotion of Comparisons')

% Now do each mouse
compare_type = {'square','circle','circ2square'};
hold on
for j = 1:length(compare_type)
    plot(repmat(h(j).XData + h(j).XOffset, num_animals,1),...
        All.ratio_plot_all.(compare_type{j}),'ko')
end
hold off

%% Simple Alignment Breakdown Plot - No Rotation Distinction, Coherent v Global only
align_type = {'distal_align','local_align','other_align','global'};

% Assemble matrices
square_mean2 = mean([sum(All.ratio_plot_all.square(:,1:3),2) All.ratio_plot_all.square(:,4)]); 
circle_mean2 = mean([sum(All.ratio_plot_all.circle(:,1:3),2) All.ratio_plot_all.circle(:,4)]); 
circ2square_mean2 = mean([sum(All.ratio_plot_all.circ2square(:,1:3),2) All.ratio_plot_all.circ2square(:,4)]); 

figure(17)
% Plot
h = bar(1:2,[square_mean2', circle_mean2', circ2square_mean2']);
set(gca,'XTickLabel',cellfun(@mouse_name_title,{'Coherent','Global Remapping'},'UniformOutput',0))
legend('Within square', 'Within circle', 'Square to Circle')
xlabel('Remapping Type')
ylabel('Proprotion of Comparisons')

% Now do each mouse
compare_type = {'square','circle','circ2square'};
hold on
for j = 1:length(compare_type)
    plot_mat = [sum(All.ratio_plot_all.(compare_type{j})(:,1:3),2) All.ratio_plot_all.(compare_type{j})(:,4)];
    plot_mat2 = plot_mat./sum(plot_mat,2); % Hack to fix an error above where I'm dividing by the wrong number to get my ratios - need to fix later
        plot(repmat(h(j).XData + h(j).XOffset, num_animals,1),...
             plot_mat2,'ko')
end
hold off

%% Alignment Breakdown Plot - Rotation and No Rotation Distinctions
rot_type = {'rotation','no_rotation'}; rot_text = {'Rotation', 'No Rotation'};
breakdown_type = {'Full', 'Simple'};

figure(18)
for m = 1:length(rot_type)
    
    %%% Full Breakdown %%%
    subplot(2, 2, (m-1)*2 + 1)
    
    % Assemble Matrices
    square_mean = mean(All.ratio_plot_all2.(rot_type{m}).square,1);
    circle_mean = mean(All.ratio_plot_all2.(rot_type{m}).circle,1);
    circ2square_mean = mean(All.ratio_plot_all2.(rot_type{m}).circ2square,1);
    
    h = bar(1:length(align_type),[square_mean', circle_mean', circ2square_mean']);
    set(gca,'XTickLabel',align_text)
    legend('Within square', 'Within circle', 'Square to Circle')
    xlabel('Remapping Type')
    ylabel('Proprotion of Comparisons')
    
    % Now do each mouse
    compare_type = {'square','circle','circ2square'};
    hold on
    for j = 1:length(compare_type)
        plot(repmat(h(j).XData + h(j).XOffset, num_animals,1),...
            All.ratio_plot_all2.(rot_type{m}).(compare_type{j}),'ko')
    end
    hold off
    if m == 2
        set(gca,'XTickLabel', {'', 'Coherent - Local/Distal Cues', 'Coherent - Other', 'Global Remapping'})
    end
    title([rot_text{m} ' - ' breakdown_type{1} ' Breakdown'])
    
    %%% Simple Breakdown %%%
    subplot(2, 2, (m-1)*2 + 2)
    
    % Assemble matrices
    square_mean2 = mean([sum(All.ratio_plot_all2.(rot_type{m}).square(:,1:3),2) ...
        All.ratio_plot_all2.(rot_type{m}).square(:,4)]);
    circle_mean2 = mean([sum(All.ratio_plot_all2.(rot_type{m}).circle(:,1:3),2) ....
        All.ratio_plot_all2.(rot_type{m}).circle(:,4)]);
    circ2square_mean2 = mean([sum(All.ratio_plot_all2.(rot_type{m}).circ2square(:,1:3),2) ....
        All.ratio_plot_all2.(rot_type{m}).circ2square(:,4)]);
    
    % Plot
    h = bar(1:2,[square_mean2', circle_mean2', circ2square_mean2']);
    set(gca,'XTickLabel',cellfun(@mouse_name_title,{'Coherent','Global Remapping'},'UniformOutput',0))
    legend('Within square', 'Within circle', 'Square to Circle')
    xlabel('Remapping Type')
    ylabel('Proprotion of Comparisons')
    
    % Now do each mouse
    compare_type = {'square','circle','circ2square'};
    hold on
    for j = 1:length(compare_type)
        plot_mat = [sum(All.ratio_plot_all2.(rot_type{m}).(compare_type{j})(:,1:3),2) ...
            All.ratio_plot_all2.(rot_type{m}).(compare_type{j})(:,4)];
        plot_mat2 = plot_mat./sum(plot_mat,2); % Hack to fix an error above where I'm dividing by the wrong number to get my ratios - need to fix later
        plot(repmat(h(j).XData + h(j).XOffset, num_animals,1),...
            plot_mat2,'ko')
    end
    hold off

    title([rot_text{m} ' - ' breakdown_type{2} ' Breakdown'])

end

%% Paired Coherent Proportion Breakdown
figure(19)
plot_type = {'ks-','ko-','kx-'};
for k = 1:length(sesh_type)
    all_coherent_rot = sum(All.ratio_plot_all2.rotation.(sesh_type{k})(:,1:3),2);
    all_coherent_no_rot = sum(All.ratio_plot_all2.no_rotation.(sesh_type{k})(:,1:3),2);
    temp = plot([all_coherent_no_rot, all_coherent_rot]',plot_type{k});
    hh(k) = temp(1);
    hold on
end
hh(4:end) = [];
xlim([0.5 2.5]);
set(gca, 'XTick', [1 2], 'XTickLabel', {'Rotation', 'No Rotation'});
ylabel('Proportion of Comparions that are Coherent')
legend(hh,'Square-to-square','Circle-to-circle','Circle-to-square')

%% Paired Coherent - Other Breakdown
figure(20)
plot_type = {'ks-','ko-','kx-'};
for k = 1:length(sesh_type)
    all_coherent_rot = sum(All.ratio_plot_all2.rotation.(sesh_type{k})(:,3),2);
    all_coherent_no_rot = sum(All.ratio_plot_all2.no_rotation.(sesh_type{k})(:,3),2);
    temp = plot([all_coherent_no_rot, all_coherent_rot]',plot_type{k});
    hh(k) = temp(1);
    hold on
end
hh(4:end) = [];
xlim([0.5 2.5]);
set(gca, 'XTick', [1 2], 'XTickLabel', {'Rotation', 'No Rotation'});
ylabel('Proportion of Comparions that are Coherent - Other')
legend(hh,'Square-to-square','Circle-to-circle','Circle-to-square')

%% Get coherent proportion vs. days between sessions

sanity_check = false(num_animals, length(sesh_type));
for k = 1:3 %length(sesh_type)
    num_sesh = length(days.(sesh_type{k}));
    time_diff_mat = repmat(days.(sesh_type{k}), num_sesh, 1) - ...
        repmat(days.(sesh_type{k})', 1, num_sesh); % Get time between sessions
    for j = 1:num_animals
        
        valid_comps = ~cellfun(@isempty,Mouse(j).corr_mat.(sesh_type{k}));
        days_bw = unique(time_diff_mat(valid_comps));
        num_coherent = 0; num_global = 0;
        for ll = 1:length(rot_type)
            temp = cat(3,Mouse(j).remapping_type2.(rot_type{ll}).distal_align.(sesh_type{k}),...
                Mouse(j).remapping_type2.(rot_type{ll}).local_align.(sesh_type{k}), ...
                Mouse(j).remapping_type2.(rot_type{ll}).other_align.(sesh_type{k}));
            temp_coherent = nansum(temp,3); % ID coherent sessions
            temp_local = Mouse(j).remapping_type2.(rot_type{ll}).local_align.(sesh_type{k}); % ID local cue coherent sessions
            temp_global = Mouse(j).remapping_type2.(rot_type{ll}).global.(sesh_type{k}); % ID global remapping sessions
            num_coherent = nansum(temp_coherent(:)) + num_coherent; % Add up numbers for later sanity check
            num_global = nansum(temp_global(:)) + num_global;
            
            % Assemble array - first col = days between, 2nd col = num
            % coherent sessions, 3rd col = num global remapping sessions,
            % 4th col = num local cue coherent sessions
            Mouse(j).coherent_v_days.(rot_type{ll}).(sesh_type{k})(:,1) = days_bw;
            for mm = 1:length(days_bw)
                days_log = time_diff_mat == days_bw(mm);
                Mouse(j).coherent_v_days.(rot_type{ll}).(sesh_type{k})(mm,2) = ...
                    nansum(temp_coherent(days_log));
                Mouse(j).coherent_v_days.(rot_type{ll}).(sesh_type{k})(mm,3) = ...
                    nansum(temp_global(days_log));
                Mouse(j).coherent_v_days.(rot_type{ll}).(sesh_type{k})(mm,4) = ...
                    nansum(temp_local(days_log));
            end
        end
        sanity_check(j,k) = sum(valid_comps(:)) == (num_coherent + num_global); % Check to make sure everything adds up
        
    end
    
end

%% Plot Coherency proportion vs time

plot_by_animal = true; %Suggest keeping false since not much is apparent on the animal level

coh_all = [];
gr_all = [];
loc_all = [];
for mm = 1:length(sesh_type)
    
    days_plot = Mouse(1).coherent_v_days.rotation.(sesh_type{mm})(:,1);
    coh_total_comb = zeros(size(days_plot));
    gr_total_comb = zeros(size(days_plot));
    local_total_comb = zeros(size(days_plot));
    
    if plot_by_animal; figure(20+mm); end
    for j = 1:num_animals

        coh_total = zeros(size(days_plot));
        gr_total = zeros(size(days_plot));
        local_total = zeros(size(days_plot));
        for k = 1:length(rot_type)
            mat_temp = Mouse(j).coherent_v_days.(rot_type{k}).(sesh_type{mm});
            
            % Get coherent/global remapping probabilities for rotation/no
            % rotation
            total_sesh = sum(mat_temp(:,2:3),2);
            coh_prop = mat_temp(:,2)./total_sesh; 
            gr_prop = mat_temp(:,3)./total_sesh;
            local_prop = mat_temp(:,4)./total_sesh;
            
            % Aggregate coherent/global probs. agnostic to rotation/no
            % rotation
            coh_total = coh_total + mat_temp(:,2);
            gr_total = gr_total + mat_temp(:,3);
            local_total = local_total + mat_temp(:,4);
            
            % Plot rotation/no-rotation breakdown
            if plot_by_animal
                subplot(3,4,4*(k-1)+j)
                bar(days_plot,[coh_prop, local_prop]);
                xlabel('Days b/w'); ylabel('Probability')
                title(['Mouse ' num2str(j) ' ' sesh_type{mm} ' ' mouse_name_title(rot_type{k})])
                ylim([0 1.5])
                xlim([-1 8])
                set(gca,'XTick',0:7)
            end
        end
        % Compute agnostic probs and plot
        total_comb = coh_total + gr_total;
        if plot_by_animal
            subplot(3,4,8+j)
            bar(days_plot,[coh_total./total_comb, local_total./total_comb])
            xlabel('Days b/w'); ylabel('Probability')
            title(['Mouse ' num2str(j) ' ' sesh_type{mm} ' Rotation Agnostic'])
            ylim([0 1.5])
            xlim([-1 8])
            set(gca,'XTick',0:7)
        end
        
        % Aggregate across all mice!
        coh_total_comb = coh_total_comb + coh_total;
        gr_total_comb = gr_total_comb + gr_total;
        local_total_comb = local_total_comb + local_total;
    end
    total_comb2 = coh_total_comb + gr_total_comb;
    figure(24)
    subplot(3,1,mm)
    bar(days_plot,[coh_total_comb./total_comb2, local_total_comb./total_comb2])
    ylim([0 1.5])
    xlim([-1 8])
    set(gca,'XTick',0:7)
    xlabel('Days b/w'); ylabel('Probability')
    title(['Rotation Agnostic Coherency v Time Breakdown - ' sesh_type{mm}])
    legend('Coherent','Coherent - Local Cues')
end

%% Plot Breakdown of alignment before, during, after
% Must run twoenv_reference beforehand to get bw_before, bw_during, &
% bw_after - this is wrong somehow - don't see that many aligned...

time_comp = {'before', 'during', 'after'};
for k = 1:length(time_comp)
    sesh_comp = bw_sesh2.(time_comp{k}); % Get indices for comparions before/during/after
    num_comps = size(sesh_comp,1); % number of sessions to compare
    All.bw_sesh2.(time_comp{k}) = zeros(1,4); % pre-allocate
    for j=1:num_animals
        for ll = 1:length(align_type)
            remap_mat = Mouse(j).remapping_type.(align_type{ll}).circ2square; % Get remapping matrix for each alignment type
            ind_use = sub2ind(size(remap_mat),sesh_comp(:,1), sesh_comp(:,2)); % Get indices from subs in sesh_comp
            Mouse(j).bw_sesh2.(time_comp{k}).(align_type{ll}) = ...
                nansum(remap_mat(ind_use));
            All.bw_sesh2.(time_comp{k})(ll) = All.bw_sesh2.(time_comp{k})(ll)+ sum(remap_mat(ind_use));
        end

    end
    
end

plot_mat = [All.bw_sesh2.before; All.bw_sesh2.during; All.bw_sesh2.after];
figure;
bar(1:length(time_comp), plot_mat./sum(plot_mat,2));
set(gca,'XTickLabel',time_comp)
ylabel('Proprotion of Sessions')
legend(cellfun(@mouse_name_title, align_type,'UniformOutput',false))
title('Circle-to-square mapping breakdown')

%% Take 2 - just plot local cue aligned sessions

plot_mat2 = [All.bw_sesh.before(2) All.bw_sesh.during(2) All.bw_sesh.after(2)];
figure;
bar(1:length(time_comp), plot_mat2./[sum(plot_mat,2)]');
set(gca,'XTickLabel',time_comp)
ylabel('Proprotion of Sessions')
% legend(cellfun(@mouse_name_title, align_type,'UniformOutput',false))
title('Circle-to-square mapping breakdown') 

%% Take 3 - just look at correlations with local cues aligned before/during/after
% Something weird here - correlations for local cue aligned sessions are
% only slightly higher for during than before/after
for k = 1:length(time_comp)
    mean_array = All.local_comps.(time_comp{k}).corr_mean;
    bda_mean(1,k) = mean(mean_array);
    bda_sem(1,k) = std(mean_array)/sqrt(length(mean_array));
end

figure
bar(bda_mean);
hold on
errorbar(bda_mean, bda_sem)

%% Aggregate before/during/after local cue aligned session probabilities for
% square-to-square, circle-to-circle, and square-to-circle

for j = 1:num_animals
    for k = 1:length(sesh_type)
        for ll = 1:length(rot_type)
            for mm = 1:length(align_type)
                remap_mat = Mouse(j).remapping_type2.(rot_type{ll})...
                    .(align_type{mm}).(sesh_type{k});
%                 if k == 1 && ll == 1 && mm == 1 % Pre-allocate variable for ALL mice
%                     All.align_v_time_ratio.(rot_type{ll}).(sesh_type{k})...
%                         .(align_type{mm}) = [];
%                 end
                for zz = 1:length(time_comp)
                    ind_use = sub2ind(size(remap_mat), bw_sesh2.(time_comp{zz})(:,1)...
                        ,bw_sesh2.(time_comp{zz})(:,2));
                    align_log = remap_mat(ind_use);
                    temp_tot = sum(~isnan(align_log)); % Get total # of sessions possible
                    good_tot = nansum(align_log); % Sum sessions of that align type
                    Mouse(j).align_v_time_ratio.(rot_type{ll}).(sesh_type{k})...
                        .(align_type{mm})(1:2,zz) = [good_tot; temp_tot];
                    
                    % Assemble #timepts x #align_types x #animals array
                    All.align_v_time_ratio.(rot_type{ll}).(sesh_type{k})...
                        (zz,mm,j) = good_tot/temp_tot; % ratio
                    All.align_v_time_total.(rot_type{ll}).(sesh_type{k})...
                        (zz,mm,j) = temp_tot; % total # comparisons
                    
                end
            end
        end
    end
end

figure(65)
for k = 1:length(sesh_type)
    for mm = 1:length(rot_type)
        subplot(4,2,2*(k-1)+mm)
        plot_mat_temp = All.align_v_time_ratio.(rot_type{mm}).(sesh_type{k});
        hb = bar(1:length(time_comp), nanmean(plot_mat_temp,3));
        hold on
        colorspec = {'ro', 'go', 'bo', 'co'};
        ht = [];
        for j = 1:num_animals
            temp = plot(repmat((1:3)',1,4) + repmat(arrayfun(@(a) a.XOffset,hb),3,1), ...
                All.align_v_time_ratio.(rot_type{mm}).(sesh_type{k})(:,:,j),colorspec{j});
            ht = [ht temp(1)];  % build up line handles for legend
        end
        hold off
        title([sesh_type{k} ' - ' mouse_name_title(rot_type{mm}) ' Breakdown'])
        set(gca,'XTickLabel',time_comp)
%         legend(ht,arrayfun(@(a) mouse_name_title(a.sesh.square(1).Animal), ...
%             Mouse,'UniformOutput',false))
        legend(hb,cellfun(@mouse_name_title,align_type,'UniformOutput',false))
    end
end

for mm = 1:2
    subplot(4,2,6+mm)
    temp = cat(3,All.align_v_time_ratio.(rot_type{mm}).circle, ...
        All.align_v_time_ratio.(rot_type{mm}).square);
    hb = bar(1:length(time_comp), nanmean(temp,3));
    title(['Circle-Circle and Square-Square Combined ' ...
        mouse_name_title(rot_type{mm}) ' Breakdown'])
    set(gca,'XTickLabel',time_comp)
    hold on
    for j=1:size(temp,3)
        plot(repmat((1:3)',1,4) + repmat(arrayfun(@(a) a.XOffset,hb),3,1), ...
            temp(:,:,j),'ko')
    end
end

%% Plot Cell recruitment for each mouse across days
new_cells = nan(4,16);
old_cells = nan(4,16);
sesh_plot = [1:8 9 11 13:16];
sesh_plot_text = {'1-1' '1-2' '2-1' '2-2' '3-1' '3-2' '4-1' '4-2' '5-1/2' '6-1/2' ...
    '7-1' '7-2' '8-1' '8-2'};
figure(35)

plot_type = 'ratio';
for j = 1:num_animals
    dirstr = ChangeDirectory_NK(Mouse(j).sesh.circ2square(1),0);
    load(fullfile(dirstr,'batch_session_map_trans.mat'));
    [new_cells(j,:), old_cells(j,:)] = cell_recruit_by_session(batch_session_map.map);
    switch plot_type
        case 'new'
            plot(new_cells(j,sesh_plot),'o');
        case 'ratio'
            plot(new_cells(j,sesh_plot)./sum(new_cells(j,sesh_plot),2),'o')
        otherwise
      
    end
    
    hold on
end

xlabel('Day-Session')
switch plot_type
    case 'new'
        plot(mean(new_cells(:,sesh_plot),1),'k-')
        ylabel('New Cells Recruited')
    case 'ratio'
        plot(mean(new_cells(:,sesh_plot)./sum(new_cells(:,sesh_plot),2),1),'k-')
        ylabel('Proportion of Recruited Cells That are New')
    otherwise
        
end
set(gca,'XTick',1:length(sesh_plot),'XTickLabel',sesh_plot_text)
hold off

%% Create PF density maps
disp('Creating PF density maps')
arena_type = {'square','circle'};
for j = 1:num_animals
    for k = 1:2
        dirstr = ChangeDirectory_NK(Mouse(j).sesh.(arena_type{k})(1),0); % 
        load(fullfile(dirstr,'batch_session_map.mat'));
        batch_map_use = fix_batch_session_map(batch_session_map);
        Mouse(j).batch_session_map.(arena_type{k}) = batch_map_use;
        for ll = 1:8
            dirstr = ChangeDirectory_NK(batch_map_use.session(ll),0); % Get base directory
            load(fullfile(dirstr,'Placefields_rot0.mat'),'TMap_gauss',...
                'RunOccMap'); % Load TMaps and Occupancy map
            temp = create_PFdensity_map(cellfun(@(a) ...
                make_binary_TMap(a),TMap_gauss,'UniformOutput',0)); % create density map from binary TMaps
            [~, Mouse(j).PFdens_map{k,ll}] = make_nan_TMap(RunOccMap,temp); % Make non-occupied pixels white
            Mouse(j).PFdensity_analysis(k).RunOccMap{ll} = RunOccMap; % save RunOccMaps for future analysis
        end
    end
end

%% Look at coherent local designation during days 5/6
