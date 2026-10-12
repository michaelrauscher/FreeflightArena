close all
clear all
files = dir('*.log');
hsRfiles = dir('TOPCAM_*.avi');
tR = datetime([hsRfiles.datenum],'ConvertFrom','datenum')';
hsLfiles = dir('SIDECAM_*.avi');
tL = datetime([hsLfiles.datenum],'ConvertFrom','datenum')';

if any([length(tL)-length(tR),length(tR)-length(files),length(tL)-length(files)]~=0);disp('!');return;end

for i = 1:length(files)
    daqn = files(i).name;
    lg = readlines(daqn);
    ts = datetime(extractAfter(lg{1},'Time: '));
    [~,mix]=min(abs(ts-tR));  
    hsr = dir([hsRfiles(mix).name(1:end-4) '*']);
    [~,mix]=min(abs(ts-tL));
    hsl = dir([hsLfiles(mix).name(1:end-4) '*']);
    lsfiles = dir([daqn(1:end-4) '*']);
    basedir = fullfile(pwd,extractBefore(daqn,'.log'));
    mkdir(basedir);
    cfiles = [hsr;hsl;lsfiles];
    for j = 1:length(cfiles)
        srcfn = fullfile(cfiles(j).folder,cfiles(j).name);
        dstfn = fullfile(basedir,cfiles(j).name);
        movefile(srcfn,dstfn);
    end
end