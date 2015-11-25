function [newpupil, totalblinksmp] = blink_interpolate(asc, data, blinksmp, plotme)
% interpolates blinks and missing data
% Anne Urai, 2015

% get the stuff we need
dat.time        = data.time{1};
dat.pupil       = data.trial{1}(find(strcmp(data.label, 'EyePupil')==1),:);
dat.gazex       = data.trial{1}(find(strcmp(data.label, 'EyeH')==1),:);
dat.gazey       = data.trial{1}(find(strcmp(data.label, 'EyeV')==1),:);

% get sample idx from asc
dat.blinksmp = blinksmp;

% initialize settings
if ~exist('plotme', 'var'); plotme = true; end % plot all this stuff

% ====================================================== %
% STEP 1: INTERPOLATE EL-DEFINED BLINKS
% ====================================================== %

if plotme,
    figure;  sp1 = subplot(511); plot(dat.time,dat.pupil);
    axis tight; box off; ylabel('Raw');
    set(gca, 'xtick', []);
end

% merge 2 blinks into 1 if they are < 250 ms together (coalesce)
coalesce = 0.250;
for b = 1:size(blinksmp, 1)-1,
    if blinksmp(b+1, 1) - blinksmp(b, 2) < coalesce * data.fsample,
        blinksmp(b, 2) = blinksmp(b+1, 2);
        blinksmp(b+1, :) = nan;
    end
end
% remove those duplicates
blinksmp(isnan(nanmean(blinksmp, 2)), :) = [];

% pad the blinks
padding       = 0.100; % how long before and after do we want to pad?
padblinksmp(:,1) = round(blinksmp(:,1) - padding * data.fsample);
padblinksmp(:,2) = round(blinksmp(:,2) + padding * data.fsample);

% make the pupil NaN at those points
for b = 1:size(padblinksmp,1),
    dat.pupil(padblinksmp(b,1):padblinksmp(b,2)) = NaN;
end

% interpolate linearly
dat.pupil(isnan(dat.pupil)) = interp1(find(~isnan(dat.pupil)), ...
    dat.pupil(~isnan(dat.pupil)), find(isnan(dat.pupil)), 'linear');

% to avoid edge artefacts at the beginning and end of file, pad in seconds
edgepad = 1;
dat.pupil(1:edgepad*data.fsample)           = NaN;
dat.pupil(end-edgepad*data.fsample : end)   = NaN;

% also extrapolate ends
dat.pupil(isnan(dat.pupil)) = interp1(find(~isnan(dat.pupil)), ...
    dat.pupil(~isnan(dat.pupil)), find(isnan(dat.pupil)), 'nearest', 'extrap');

if plotme, sp2 = subplot(512); hold on;
    % show how well this worked
    plot(dat.time, dat.pupil);
    axis tight; box off; ylabel('EyeLink interpolated');
    set(gca, 'xtick', []);
end

% ====================================================== %
% STEP 2: INTERPOLATE PEAK-DETECTED BLINKS
% ====================================================== %

dat.pupildiff = diff(dat.pupil) - mean(diff(dat.pupil)) / std(diff(dat.pupil));
[peaks, loc] = findpeaks(dat.pupildiff, 'minpeakheight', 50, 'minpeakdistance', 0.5*data.fsample);

if plotme, sp3 = subplot(513);
    plot(dat.time(2:end), dat.pupildiff); hold on;
    stem(loc, peaks);
    axis tight; box off; ylabel('Peak detect');
    set(gca, 'xtick', []);
end

% convert peaks into blinksmp
newblinksmp = nan(length(peaks), 2);
for p = 1:length(peaks),
    newblinksmp(p, 1) = loc(p) - padding * data.fsample;
    newblinksmp(p, 2) = loc(p) + padding * data.fsample;
end

% make the pupil NaN at those points
for b = 1:size(newblinksmp,1),
    dat.pupil(newblinksmp(b,1):newblinksmp(b,2)) = NaN;
end

% interpolate linearly
dat.pupil(isnan(dat.pupil)) = interp1(find(~isnan(dat.pupil)), ...
    dat.pupil(~isnan(dat.pupil)), find(isnan(dat.pupil)), 'linear');

if plotme,
    sp4 = subplot(514); plot(dat.time, dat.pupil);
    axis tight; box off; ylabel('Clean');
    set(gca, 'xtick');
end

% output the full blinksample matrix
totalblinksmp = [blinksmp; newblinksmp];

% sort
totalblinksmp = sort(totalblinksmp);
newpupil = dat.pupil;

% link axes
if plotme, 
    linkaxes([sp1 sp2 sp3 sp4], 'x'); 
    xlim([-10 dat.time(end)+10]);
end

end


