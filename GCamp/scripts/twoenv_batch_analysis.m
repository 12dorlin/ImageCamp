% Batch script for two-env experiment

%% Set up mega-variable - note that working_dir 1 = square sessions and 2 = octagon sessions (REQUIRED)

Mouse(1).Name = 'G30';
Mouse(1).working_dirs{1} = 'J:\GCamp Mice\Working\G30\2env\11_19_2014\1 - 2env square left 201B\Working';
Mouse(1).working_dirs{2} = 'J:\GCamp Mice\Working\G30\2env\11_20_2014\1 - 2env octagon left\Working';

Mouse(2).Name = 'G31';
Mouse(2).working_dirs{1} = 'J:\GCamp Mice\Working\G31\2env\12_15_2014\1 - 2env square right\Working';
Mouse(2).working_dirs{2} = 'J:\GCamp Mice\Working\G31\2env\12_16_2014\1 - 2env octagon left\Working';

num_animals = length(Mouse);

for j = 1:num_animals
    Mouse(j).key = '1,1 = square no-rotate, 1,2 = octagon no-rotate, 2,1 = square rotate, 2,2 = octagon rotate';
end

%% Run tmap_corr_across_days for all conditions

for j = 1:num_animals
    for k = 1:length(Mouse(j).working_dirs)
        for m = 0:1
            Mouse(j).corr_matrix{m+1,k} = tmap_corr_across_days(Mouse(j).working_dirs{k},'rotate_to_std',m);
        end
    end
end

%% Dump means into a mega-matrix (combine ALL correlation values here also to get a mega cdf for each session?)

num_sessions = size(Mouse(1).corr_matrix{1},1);
% mega_mean(1).matrix = cell(num_sessions,num_sessions); % No rotate
% mega_mean(2).matrix = cell(num_sessions,num_sessions); % rotate

for ll = 1:num_sessions
    for mm = 1:num_sessions
        count = 1; % Start counter
        for j = 1:num_animals
            for k = 1:2
                mega_mean_rot_temp = nanmean(squeeze(Mouse(j).corr_matrix{2,k}(ll,mm,:)));
                mega_mean_no_rot_temp = nanmean(squeeze(Mouse(j).corr_matrix{1,k}(ll,mm,:)));
                
                mega_mean(1).matrix(ll,mm,count) = mega_mean_no_rot_temp; % [mega_mean(1).matrix(ll,mm) mega_mean_no_rot_temp];
                mega_mean(2).matrix(ll,mm,count) = mega_mean_rot_temp; % [mega_mean(2).matrix(ll,mm) mega_mean_rot_temp];
                count = count + 1;
            end
        end
    end
    
end

%% Get basic stats

% Better way to do things in the future is to get mean d
mean_simple_norot = mean(mega_mean(1).matrix,3);
mean_simple_rot = mean(mega_mean(2).matrix,3);

% Indices for various comparisons - wow, that's a lot of work
before_win = [1 2 ; 1 3; 1 4; 2 3; 2 4; 3 4]; before_win_ind = sub2ind([8 8 4],before_win(:,1), before_win(:,2));
before_win_norot = [1 2; 1 4; 2 4; 3 4]; before_win_norot_ind = sub2ind([8 8 4],before_win(:,1), before_win(:,2));
after_win = [7 8]; after_win_ind = sub2ind([8 8 4],after_win(:,1), after_win(:,2));
after_win_norot = [7 8]; after_win_norot_ind = sub2ind([8 8 4],after_win_norot(:,1), after_win_norot(:,2));
before_after = [1 7; 2 7; 3 7; 4 7; 1 8; 2 8 ;3 8; 4 8]; before_after_ind = sub2ind([8 8 4],before_after(:,1), before_after(:,2));
before_after_norot = [2 7; 4 7; 1 8; 2 8 ; 3 8]; before_after_norot_ind = sub2ind([8 8 4],before_after_norot(:,1), before_after_norot(:,2));
before_5 = [1 5; 2 5; 3 5; 4 5]; before_5_ind = sub2ind([8 8 4],before_5(:,1), before_5(:,2));
before_5_norot = [2 5; 4 5]; before_5_norot_ind = sub2ind([8 8 4],before_5_norot(:,1), before_5_norot(:,2));
before_6 = [1 6; 2 6 ; 3 6; 4 6]; before_6_ind = sub2ind([8 8 4],before_6(:,1), before_6(:,2));
before_6_norot = [1 6; 2 6; 3 6; 4 6]; before_6_norot_ind = sub2ind([8 8 4],before_6_norot(:,1), before_6_norot(:,2));
after_5 = [5 7; 5 8]; after_5_ind = sub2ind([8 8 4],after_5(:,1), after_5(:,2));
after_5_norot = [5 8]; after_5_norot_ind = sub2ind([8 8 4],after_5_norot(:,1), after_5_norot(:,2));
after_6 = [6 7; 6 8]; after_6_ind = sub2ind([8 8 4],after_6(:,1), after_6(:,2));
after_6_norot = [6 7; 6 8]; after_6_norot_ind = sub2ind([8 8 4],after_6_norot(:,1), after_6_norot(:,2));


before_win_mean = mean(mean_simple_rot(before_win_ind));
before_win_sem = std(mean_simple_rot(before_win_ind))/sqrt(length(before_win_ind));
before_win_norot_mean = mean(mean_simple_norot(before_win_norot_ind));
before_win_norot_sem = std(mean_simple_norot(before_win_norot_ind))/sqrt(length(before_win_norot_ind));

before_after_mean = mean(mean_simple_rot(before_after_ind));
before_after_sem = std(mean_simple_rot(before_after_ind))/sqrt(length(before_after_ind));
before_after_norot_mean = mean(mean_simple_norot(before_after_norot_ind));
before_after_norot_sem = std(mean_simple_norot(before_after_norot_ind))/sqrt(length(before_after_norot_ind));

before_5_mean = mean(mean_simple_rot(before_5_ind));
before_5_sem = std(mean_simple_rot(before_5_ind))/sqrt(length(before_5_ind));
before_5_norot_mean = mean(mean_simple_norot(before_5_norot_ind));
before_5_norot_sem = std(mean_simple_norot(before_5_norot_ind))/sqrt(length(before_5_norot_ind));

before_6_mean = mean(mean_simple_rot(before_6_ind));
before_6_sem = std(mean_simple_rot(before_6_ind))/sqrt(length(before_6_ind));
before_6_norot_mean = mean(mean_simple_norot(before_6_norot_ind));
before_6_norot_sem = std(mean_simple_norot(before_6_norot_ind))/sqrt(length(before_6_norot_ind));

after_5_mean = mean(mean_simple_rot(after_5_ind));
after_5_sem = std(mean_simple_rot(after_5_ind))/sqrt(length(after_5_ind));
after_5_norot_mean = mean(mean_simple_norot(after_5_norot_ind));
after_5_norot_sem = std(mean_simple_norot(after_5_norot_ind))/sqrt(length(after_5_norot_ind));

after_6_mean = mean(mean_simple_rot(after_6_ind));
after_6_sem = std(mean_simple_rot(after_6_ind))/sqrt(length(after_6_ind));
after_6_norot_mean = mean(mean_simple_norot(after_6_norot_ind));
after_6_norot_sem = std(mean_simple_norot(after_6_norot_ind))/sqrt(length(after_6_norot_ind));

figure
h = bar([before_win_mean, before_win_norot_mean; before_after_mean, before_after_norot_mean; ...
    before_5_mean, before_5_norot_mean; after_5_mean, after_5_norot_mean; ...
    before_6_mean, before_6_norot_mean; after_6_mean, after_6_norot_mean]);
hold on
set(gca,'XTickLabel',{'Before within','Before-After','Before-Day5','After-Day5',...
    'Before-Day6','After-Day6'})
ylabel('Transient Map Mean Correlations')
legend('Rotated (local cues align)','Not-rotated (distal cues align)')
