function [data] = blink_interpolate_regressout(asc, data, plotme)
% interpolates blinks and missing data, then regresses out the pupil
% response to blinks and saccades (as defined by eyelink
% Anne Urai, 2015

% get the stuff we need
dat.time        = data.time;
dat.pupil       = data.trial{1}(find(strcmp(data.label, 'EyePupil')==1),:);
dat.gazex       = data.trial{1}(find(strcmp(data.label, 'EyeH')==1),:);
dat.gazey       = data.trial{1}(find(strcmp(data.label, 'EyeV')==1),:);
dat.blinksmp    = asc.blinksmp;
dat.saccsmp     = asc.saccsmp;

% initialize settings
if ~exist('plotme', 'var'); plotme = true; end % plot all this stuff

% ====================================================== %
% STEP 1: INTERPOLATE EL-DEFINED BLINKS
% ====================================================== %

if plotme,
    figure;  subplot(511); plot(data.time,data.pupil, 'k');
    axis tight; box off; ylabel('Raw');
end

% pad the blinks
padding       = 0.100; % how long before and after do we want to pad?
blinksmp(:,1) = round(dat.blinksmp(:,1) - padding * data.fsample);
blinksmp(:,2) = round(dat.blinksmp(:,2) + padding * data.fsample); 

% make the pupil NaN at those points
for b = 1:size(blinksmp,1),
    dat.pupil(blinksmp(b,1):blinksmp(b,2)) = NaN;
end

% interpolate linearly
dat.pupil(isnan(dat.pupil)) = interp1(find(~isnan(dat.pupil)), ...
    dat.pupil(~isnan(dat.pupil)), find(isnan(dat.pupil)), 'linear');

% to avoid edge artefacts at the beginning and end of file, pad
edgepad = 1;
dat.pupil(1:edgepad*data.fsample)           = NaN;
dat.pupil(end-edgepad*data.fsample : end)   = NaN;

% also extrapolate ends
dat.pupil(isnan(dat.pupil)) = interp1(find(~isnan(dat.pupil)), ...
    dat.pupil(~isnan(dat.pupil)), find(isnan(dat.pupil)), 'nearest', 'extrap');

if plotme, subplot(511), hold on;
    plot(dat.pupil, 'r');
end
    
% ====================================================== %
% STEP 2: INTERPOLATE PEAK-DETECTED BLINKS
% ====================================================== %
   

% smooth the signal a bits
win             = hanning(11);
pupildatsmooth  = filter2(win.',pupildat,'same');
% pupildatsmooth  = pupildat;
pupildattest    = pupildatsmooth;

% compute the velocity
velocity    = diff(pupildatsmooth);
cutoff      = threshold; % arbitrary, might differ per file/subject

% find blinks
blinkstart  = find(velocity<-cutoff);
blinkend    = find(velocity> cutoff);

% assert that these points make sense
blinksmp = [];
for b = 1:length(blinkstart),
    
    % for each blinkstart, find the first blinkend
    if b > 1 && blinkstart(b) - blinkstart(b-1) < 0.01 * data.fsample,
        continue % if blinkstarts are too close together, skip
    end
    
    % find the two samples that go together
    thisblinkstart = blinkstart(b);
    thisblinkend   = blinkend(find(blinkend > thisblinkstart, 1, 'first'));
    
    % check if there is missing data in between
    blinkdat = pupildatsmooth(thisblinkstart:thisblinkend);
    cutoff2   = max([median(pupildatsmooth)- 1*std(pupildatsmooth) 0]);
    if (length(find(blinkdat <= cutoff2)) / length(blinkdat)) > 0.3,
        % if the data consists mainly of 0s,
        blinksmp = [ blinksmp; ...
            thisblinkstart thisblinkend];
    end
end

if plotme,
    s1 = subplot(511);
    % check visually
    plot(timeaxis,pupildatsmooth, 'b');
    axis tight; box off;
    
    s2 = subplot(512);
    hold on;
    
    plot(timeaxis(1:end-1), velocity, 'g');
    try
        plot(blinksmp(:,1)*data.fsample, ones(1, length(blinksmp)), 'k.', 'MarkerSize', 10);
        plot(blinksmp(:,2)*data.fsample, ones(1, length(blinksmp)), 'r.', 'MarkerSize', 10);
    end
    l = line(get(gca, 'XLim'), [cutoff cutoff]); set(l, 'Color', 'k');
    l = line(get(gca, 'XLim'), [-cutoff -cutoff]); set(l, 'Color', 'k');
    axis tight;
    linkaxes([s1 s2], 'x');
    box off;
end


% add some padding around the blinks as they have been detected
if ~isempty(blinksmp),
    padding       = 0.150; % 150 ms
    blinksmp(:,1) = round(blinksmp(:,1) - padding * data.fsample);
    blinksmp(:,2) = round(blinksmp(:,2) + 2 * padding * data.fsample); % need more padding after blink
    
    % if any points went outside the domain of the signal, put back
    blinksmp(find(blinksmp < 1)) = 1;
    blinksmp(find(blinksmp > length(pupildatsmooth))) = length(pupildatsmooth);
    
    % make the pupil NaN at those points
    for b = 1:size(blinksmp,1),
        pupildatsmooth(blinksmp(b,1):blinksmp(b,2)) = NaN;
    end
end

% set anything that's still zero to NaN
pupildatsmooth(pupildatsmooth==0) = NaN;
pupildatsmooth(find(pupildatsmooth< nanmedian(pupildatsmooth) - 3*nanstd(pupildatsmooth))) = NaN;

% linear interpolation
pupildatsmooth(isnan(pupildatsmooth)) = interp1(find(~isnan(pupildatsmooth)), ...
    pupildatsmooth(~isnan(pupildatsmooth)), find(isnan(pupildatsmooth)), 'linear');

pupildatclean = pupildatsmooth;

if plotme,
    s3 = subplot(513);
    plot(timeaxis, pupildattest, 'Color', [0.8 0.8 0.8]); hold on;
    plot(timeaxis, pupildatsmooth, 'r');
    axis tight; box off;
    %ylim([median(pupildatclean) - 3*std(pupildatclean) median(pupildatclean) + 3*std(pupildatclean)]);
    %ylim([0 8*10^4]);
end

% !!! make a second pass on the velocity
blinksmpsave  = blinksmp; % for output

clear blinksmp blinkstart blinkend
% compute the velocity
velocity    = diff(pupildatclean);
cutoff      = threshold * 2; % arbitrary, might differ per file/subject
padding     = 0.150; % 150 ms

% find blinks
blinkstart  = find(velocity<-cutoff);
blinkend    = find(velocity> cutoff);

% assert that these points make sense
blinksmp = [];
for b = 1:length(blinkstart),
    % for each blinkstart, find the first blinkend
    if b > 1 && blinkstart(b) - blinkstart(b-1) < 0.001 * data.fsample,
        disp(b);
        continue % if blinkstarts are too close together, skip
    end
    
    % find the two samples that go together
    thisblinkstart = blinkstart(b);
    thisblinkend   = blinkend(find(blinkend > thisblinkstart, 1, 'first'));
    
    % check if there is missing data in between
    if thisblinkstart + 1 * data.fsample > thisblinkend,
        % if the data consists mainly of 0s,
        blinksmp = [ blinksmp; ...
            thisblinkstart thisblinkend];
    end
end

if ~isempty(blinksmp), %add some padding around the blinks as they have been detected
    
    blinksmp(:,1) = round(blinksmp(:,1) - padding * data.fsample);
    blinksmp(:,2) = round(blinksmp(:,2) + 2 * padding * data.fsample); % need more padding after blink
    
    % if any points went outside the domain of the signal, put back
    blinksmp(find(blinksmp < 1)) = 1;
    blinksmp(find(blinksmp > length(pupildatclean))) = length(pupildatclean);
    
    if plotme,
        s4 = subplot(514);
        plot(timeaxis(1:end-1), velocity); hold on;
        plot(blinksmp(:,1)*data.fsample, ones(1, length(blinksmp)), 'k.', 'MarkerSize', 10);
        plot(blinksmp(:,2)*data.fsample, ones(1, length(blinksmp)), 'r.', 'MarkerSize', 10);
        ylim([-1000 1000]);
        l = line(get(gca, 'XLim'), [cutoff cutoff]); set(l, 'Color', 'k');
        l = line(get(gca, 'XLim'), [-cutoff -cutoff]); set(l, 'Color', 'k');
        axis tight; box off;
    end
    
    % make the pupil NaN at those points
    for b = 1:size(blinksmp,1),
        pupildatclean(blinksmp(b,1):blinksmp(b,2)) = NaN;
    end
end

% set anything that's still zero to NaN
pupildatclean(pupildatclean==0) = NaN;
pupildatclean(find(pupildatclean< nanmedian(pupildatclean) - 3*nanstd(pupildatclean))) = NaN;

% interpolate
pupildatclean(isnan(pupildatclean)) = interp1(find(~isnan(pupildatclean)), ...
    pupildatclean(~isnan(pupildatclean)), find(isnan(pupildatclean)), 'linear');

% to avoid edge artefacts (can be huge when zscoring), pad ends
edgepad = 1; % s
pupildatclean(1:edgepad*data.fsample)           = NaN;
pupildatclean(end-edgepad*data.fsample : end)   = NaN;

% also extrapolate ends
pupildatclean(isnan(pupildatclean)) = interp1(find(~isnan(pupildatclean)), ...
    pupildatclean(~isnan(pupildatclean)), find(isnan(pupildatclean)), 'nearest', 'extrap');

if plotme,
    s5 = subplot(515);
    plot(timeaxis, pupildatsmooth, 'Color', [0.8 0.8 0.8]); hold on;
    plot(timeaxis, pupildatclean, 'r');
    axis tight; box off;
    set(gca, 'TickDir', 'out', 'box', 'off', 'XTick', []);
    
    try
        linkaxes([s1 s2 s3 s4 s5], 'x');
        set([s1 s2 s3 s4 s5], 'TickDir', 'out', 'box', 'off', 'XTick', []);
    catch
        linkaxes([s1 s2 s3], 'x');
        set([s1 s2 s3], 'TickDir', 'out', 'box', 'off', 'XTick', []);
    end
    curxlim = get(gca, 'XLim');
    xlim([-5000000 curxlim(2)]); %  make the beginning of the signal visible
    suplabel(filename, 't');
    suplabel('Time (s)', 'x');
    saveas(gcf, regexprep(filename, '.mat', '_blinkinterp.png'), 'png');
    disp(['saved ' regexprep(filename, '.mat', '_blinkinterp.png')]);
end

blinksmp = blinksmpsave; % output
data.trial{1}(pupilchan, :) = pupildatclean;

end


