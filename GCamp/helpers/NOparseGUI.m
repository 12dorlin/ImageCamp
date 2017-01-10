function NOparseGUI( ~,~ )
% Tool to facilitate parsing AVI for DNMP task into event time stamps (frame numbers),
% export those numbers in an excel sheet for using with Nat's DNMP
% functions. Select lap number, toggle between frames, click button to set
% that frame number as that type of event. Have to click away from button
% on figure for going between frames to work. If lap number button is red, click it to 
% start logging on that lap number

%% Nat to-do for making NO tracker
% 3) Add in update to show which object was selected for a given frame
% 4) Change button names/eliminate buttons
% 5) Make sure that you can re-start a previous session if it crashes -
% re-load NOvar variable AND pop up dialog box letting them know this is
% happening. *******


%%
global miscVar
global videoFig
global NOVar

msgbox({'Notes on use:';' Q/R - step back/forward 10 seconds';...
        ' A/F - step back/forward 1 second'; ' numpad1 = mouse exploring lower-left object'; ...
        ' numpad9 = mouse exploring upper-right object '; ' numpad5 = mouse NOT exploring either object'; ...
        ' (use to fix mistaken numpad9 or numpad1 push'; ' ';...
        'Click off of button for keyboard!'})

miscVar.panelHeight = 480;
videoFig.videoPanel = figure('Position',[100,100,900,miscVar.panelHeight],'MenuBar','none','KeyPressFcn',@keyPress);
videoFig.plotted = subplot(1,2,1,'Position',[0.05,0.1,0.55,0.8]);
title('Frame 1/lots')

miscVar.upperLimit = miscVar.panelHeight - 120;
miscVar.buttonStepDown = 40;
miscVar.buttonLeftEdge = 560;
miscVar.buttonMiddleEdge = 622;
miscVar.buttonSecondCol = 705;
miscVar.buttonWidth = 130;
miscVar.Gray=[0.94,0.94,0.94];
miscVar.Red=[1,0.5,0.5];
miscVar.Green = [0.5 1 0.5];
miscVar.VideoLoadedFlag=0;
miscVar.LapsWorkedOn=[];

NOVar.LLframes = [];
NOVar.URframes = [];   
NOVar.Questionable = [];
%% Layout for Novel Object
fcnLoadVideo;
miscVar.buttonsInUse={'UpperRightButton';'NeitherButton';...
    'LowerLeftButton';'QuestionableButton'}; 

videoFig.UpperRightButton = uicontrol('Style','pushbutton','String','UPPER RIGHT OBJECT (9)',...
                             'Position',[miscVar.buttonSecondCol,miscVar.upperLimit, miscVar.buttonWidth,30],...
                             'Callback',{@fcnUpperRightButton});
                         
videoFig.NeitherButton = uicontrol('Style','pushbutton','String','NEITHER (5)',...
                             'Position',[miscVar.buttonMiddleEdge,miscVar.upperLimit - miscVar.buttonStepDown*1,...
                             miscVar.buttonWidth,30], 'Callback',{@fcnNeitherButton});
                         
videoFig.LowerLeftButton = uicontrol('Style','pushbutton','String','LOWER LEFT OBJECT (1)',...
                             'Position',[miscVar.buttonLeftEdge,miscVar.upperLimit - miscVar.buttonStepDown*2,...
                             miscVar.buttonWidth,30], 'Callback',{@fcnLowerLeftButton});
                         
videoFig.QuestionableButton = uicontrol('Style','pushbutton','String','QUESTIONABLE',...
                             'Position',[miscVar.buttonMiddleEdge,miscVar.upperLimit - miscVar.buttonStepDown*3,...
                             miscVar.buttonWidth,30], 'Callback',{@fcnQuestionableButton});
                         
%% Other buttons
                         
videoFig.LoadVideoButton = uicontrol('Style','pushbutton','String','LOAD VIDEO',...
                             'Position',[miscVar.buttonLeftEdge,miscVar.upperLimit - miscVar.buttonStepDown*6,...
                             miscVar.buttonWidth,30],'Callback',{@fcnLoadVideo}); 
                 
videoFig.JumpFrameButton = uicontrol('Style','pushbutton','String','JUMP TO TIME',...
                             'Position',[miscVar.buttonLeftEdge,miscVar.upperLimit - miscVar.buttonStepDown*7,...
                             miscVar.buttonWidth,30], 'Callback',{@fcnJumpFrameButton});

end

%% Button Functions
function fcnUpperRightButton(~,~)
global miscVar
if miscVar.VideoLoadedFlag==1
    fcnAddUR
    updatebuttoncolor
end
end

function fcnNeitherButton(~,~)
global miscVar
if miscVar.VideoLoadedFlag==1
    fcnNeither
    updatebuttoncolor

end
end

function fcnLowerLeftButton(~,~)
global miscVar
if miscVar.VideoLoadedFlag==1
    fcnAddLL
    updatebuttoncolor
end
end

function fcnQuestionableButton(~,~)
global miscVar
if miscVar.VideoLoadedFlag==1
    fcnQuestionableTag
    updatebuttoncolor
end
end
%%
function fcnJumpFrameButton(~,~)
global videoFig
global miscVar
global video

if miscVar.VideoLoadedFlag==1
    try
        jumpSec = inputdlg('Jump to what second?');
        switch mod(str2double(jumpSec{:}),1)==0
            case 0
                msgbox('Time must be an integer','Error','error')
            case 1
                jumpSec=str2double(jumpSec{:});
                jumpFrame = jumpSec*30+1;
                if jumpFrame>0 && jumpFrame <=miscVar.totalFrames
                    miscVar.frameNum = jumpFrame-1;
                    video.CurrentTime = miscVar.frameNum/video.FrameRate;
                    miscVar.currentFrame = readFrame(video);
                    miscVar.frameNum = miscVar.frameNum + 1;
                    videoFig.plotted = imagesc(miscVar.currentFrame);
                    title(['Time ' num2str(round(miscVar.frameNum/30)) ' / ' num2str(round(miscVar.totalFrames/30)) ' seconds'])
                    fcnSaveNOVar
                else   
                    msgbox('Time must in range','Error','error')
                end
        end
    catch
        msgbox('Why would you even?')
    end 
end    
end

%%
function fcnLoadVideo(~,~)
global videoFig
global miscVar
global NOVar
global video

try
    [NOVar.FileName, NOVar.PathName] = uigetfile('*.AVI','Select the AVI file');
    video = VideoReader(fullfile(NOVar.PathName, NOVar.FileName));
    miscVar.currentTime = 0;
    miscVar.currentFrame = readFrame(video);
    miscVar.currentTime = miscVar.currentTime+video.FrameRate^-1;
    miscVar.frameNum = 1;
    miscVar.totalFrames = video.Duration/video.FrameRate^-1;
    videoFig.plotted;
    imagesc(miscVar.currentFrame);
    title(['Time ' num2str(round(miscVar.frameNum/30)) ' / ' num2str(round(miscVar.totalFrames/30)) ' seconds'])
    miscVar.VideoLoadedFlag=1;
    videoFig.Name=NOVar.FileName;
    NOVar.LastFrame = 1; % Last frame viewed tracker
    
    % Check for existing NOtracking in workspace, prompt to load it 
    if exist(fullfile(NOVar.PathName, 'NOtracking.mat'),'file')
        temp = importdata(fullfile(NOVar.PathName, 'NOtracking.mat'));
        if exist(fullfile(temp.PathName, temp.FileName),'file')
            use_existing = input('Existing NOVar.mat file found.  Do you wish use? (y/n - Note that ''n'' will overwrite existing file): ', 's');
            if strcmpi(use_existing,'y')
                load(fullfile(NOVar.PathName, 'NOtracking.mat'));
                NOVar = NOtracking;
            elseif strcmpi(use_existing,'n')
                save(fullfile(NOVar.PathName, 'NOtracking_old.mat'),'temp');
            end
        end
    end
    
catch
    disp('Something went wrong')
end
end

%%
function keyPress(~, e)%src

global miscVar
global videoFig
global video

%pause(0.001)
%e.Key

switch e.Key
    case 'a' %Step back 30
        if video.currentTime > 30/video.FrameRate
            miscVar.frameNum = miscVar.frameNum - 31;
            video.CurrentTime = miscVar.frameNum/video.FrameRate;
            miscVar.currentFrame = readFrame(video);
            miscVar.frameNum = miscVar.frameNum + 1;
            videoFig.plotted = imagesc(miscVar.currentFrame);
            updatetitletime
            updatebuttoncolor
            fcnSaveNOVar
        end
    case 'f' %Step forward 30  
        if video.currentTime+1 <= miscVar.totalFrames/30
            miscVar.frameNum = miscVar.frameNum + 29;
            video.CurrentTime = miscVar.frameNum/video.FrameRate;
            miscVar.currentFrame = readFrame(video);
            miscVar.frameNum = miscVar.frameNum + 1;
            videoFig.plotted = imagesc(miscVar.currentFrame);
            updatetitletime
            updatebuttoncolor
            fcnSaveNOVar
        end

    case 'numpad1' % log framenum as LL
        fcnAddLL
        updatebuttoncolor
        
    case 'numpad9' % log framenum as UR
        fcnAddUR
        updatebuttoncolor
        
    case 'numpad5' % remove framenum from LL or UR
        fcnNeither
        updatebuttoncolor

    case 'space'    
        disp('Fake player start/stop')
end
         
end
%% Update time in title
function updatetitletime(~,~)
global miscVar

title(['Time ' num2str(round(miscVar.frameNum/30)) ' / ' num2str(floor(miscVar.totalFrames/30)) ' seconds'])
end

%% Refresh buttons color
function updatebuttoncolor(~,~)
global NOVar
global miscVar
global videoFig

% Identify if mouse is exploring either object
LLactive = ~isempty(NOVar) && any(NOVar.LLframes == miscVar.frameNum);
URactive = ~isempty(NOVar) && any(NOVar.URframes == miscVar.frameNum);

% Set all buttons to gray
for buttonCol=1:length(miscVar.buttonsInUse)
    eval(['videoFig.',miscVar.buttonsInUse{buttonCol},'.BackgroundColor=miscVar.Gray;'])
end

% Make appropriate button red
if LLactive && ~URactive
    videoFig.LowerLeftButton.BackgroundColor=miscVar.Red;
elseif ~LLactive && URactive
    videoFig.UpperRightButton.BackgroundColor=miscVar.Red;
elseif ~LLactive && ~URactive
    videoFig.NeitherButton.BackgroundColor=miscVar.Red;
elseif LLactive && URactive
    error('Something wrong - mouse appears to be exploring both objects at the same time')
end

% Tag as questionable if desired
if any(miscVar.frameNum == NOVar.Questionable)
    videoFig.QuestionableButton.BackgroundColor=miscVar.Red;
end

end

%% Add Lower-Left exploration
function fcnAddLL(~,~)
global NOVar
global miscVar

NOVar.LLframes = unique([NOVar.LLframes miscVar.frameNum]); % Add existing frame number if unique and sort it
NOVar.nLL = length(NOVar.LLframes); %
if any(miscVar.frameNum == NOVar.URframes) % remove from NOVar.URframes if there already
    ind_remove = miscVar.frameNum == NOVar.URframes;
    NOVar.URframes = NOVar.URframes(~ind_remove);
    NOVar.nUR = length(NOVar.URframes);
    disp(['Frame ' num2str(miscVar.frameNum) ' REMOVED from upper-right object exploration count'])
end
disp(['Frame ' num2str(miscVar.frameNum) ' ADDED to lower-left object exploration count'])

fcnSaveNOVar
% save NOVar NOVar

end
%% Add Upper-Right exploration
function fcnAddUR(~,~)
global NOVar
global miscVar

NOVar.URframes = unique([NOVar.URframes miscVar.frameNum]); % Add existing frame number if unique and sort it
NOVar.nUR = length(NOVar.URframes); %
if any(miscVar.frameNum == NOVar.LLframes) % remove from NOVar.LLframes if there already
    ind_remove = miscVar.frameNum == NOVar.LLframes;
    NOVar.LLframes = NOVar.LLframes(~ind_remove);
    NOVar.nLL = length(NOVar.LLframes);
    disp(['Frame ' num2str(miscVar.frameNum) ' REMOVED from lower-left object exploration count'])
end
disp(['Frame ' num2str(miscVar.frameNum) ' ADDED to upper-right object exploration count'])

fcnSaveNOVar
% save NOVar NOVar

end

%% Remove Upper-Right/Lower-Left exploration
function fcnNeither(~,~)
global NOVar
global miscVar

if any(miscVar.frameNum == NOVar.LLframes) % remove from NOVar.LLframes if there already
    ind_remove = miscVar.frameNum == NOVar.LLframes;
    NOVar.LLframes = NOVar.LLframes(~ind_remove);
    NOVar.nLL = length(NOVar.LLframes);
    disp(['Frame ' num2str(miscVar.frameNum) ' REMOVED from lower-left object exploration count'])
elseif any(miscVar.frameNum == NOVar.URframes) % remove from NOVar.URframes if there already
    ind_remove = miscVar.frameNum == NOVar.URframes;
    NOVar.URframes = NOVar.URframes(~ind_remove);
    NOVar.nUR = length(NOVar.URframes);
    disp(['Frame ' num2str(miscVar.frameNum) ' REMOVED from upper-right object exploration count'])
else
    disp(['Frame ' num2str(miscVar.frameNum) ' isn''t already logged as lower-left or upper-right object exploration.'])
end

fcnSaveNOVar
% save NOVar NOVar

end

%% Tag as questionable
function fcnQuestionableTag(~,~)
global NOVar
global miscVar

qbool = miscVar.frameNum == NOVar.Questionable;
if any(qbool) % If already tagged, remove it
    NOVar.Questionable = NOVar.Questionable(~qbool);
else % Add it if not tagged
    NOVar.Questionable = [NOVar.Questionable, miscVar.frameNum];
end
   
end

%% Save NOVar to workspace as non-global variable
function fcnSaveNOVar(~,~)
global NOVar
global miscVar
NOtracking.LLframes = NOVar.LLframes;
NOtracking.URframes = NOVar.URframes;
NOtracking.nUR = NOVar.nUR;
NOtracking.nLL = NOVar.nLL;
NOtracking.PathName = NOVar.PathName;
NOtracking.FileName = NOVar.FileName;
NOtracking.Questionable = NOVar.Questionable;

% Update frame viewed
NOVar.LastFrame = max([NOVar.LastFrame,miscVar.frameNum]);
NOtracking.LastFrame = NOVar.LastFrame;
time_use = round(NOtracking.LastFrame/30);
if time_use < floor(miscVar.totalFrames/30)
    xlabel('YOU STILL HAVE FRAMES LEFT TO VIEW','Color','Red')
else
    xlabel('You have viewed all frames','Color','Black')
end

save(fullfile(NOtracking.PathName,'NOtracking.mat'),'NOtracking');

end

