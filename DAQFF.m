% ts = linspace(0,1,d.Rate);
% sig = chirp(ts,180,ts(end),180)';
% sig = [zeros(d.Rate,1); sig];
% sig = [[zeros(d.Rate,1);repmat(3,d.Rate,1)] sig];
% sig = [sig;zeros(d.Rate*5,2)];
% [data,tstamps,trigt]=readwrite(d,sig,'OutputFormat','matrix');
% plot(tstamps,data);

function DAQFF()
s=serialport('COM4',2E6);
configureCallback(s,"terminator",@readtemphumidity);

daqreset;
d = daq('ni');
d.Rate = 48000;
addoutput(d,'Dev1',"ao0","Voltage");
addoutput(d,'Dev1',"ao1","Voltage");
addoutput(d,'Dev1',"ao2","Voltage");

daqdata = [];
r = daq('ni');
r.Rate = 48000;
addinput(r,'Dev1',"ai0","Voltage");
addinput(r,'Dev1',"ai1","Voltage");
addinput(r,'Dev1',"ai4","Voltage"); %interlock
addinput(r,'Dev1',"ai2","Voltage");%cam arm
addinput(r,'Dev1',"ai3","Voltage");%cam arm
r.ScansAvailableFcn = @getdaq;
r.ScansAvailableFcnCount = round(r.Rate/2);
% ttt=linspace(1/d.Rate,.25,d.Rate);
% chp = chirp(ttt,2000,ttt(end),2000,'linear',-90);
% chp = chp'*.5;

interlock = daq('ni');
addoutput(interlock,'Dev1',"port0/line23",'Digital');
write(interlock,1);

mark = repmat(3,floor(d.Rate*.004),1);
space = zeros(floor(d.Rate*.004),1);
smts = linspace(1/d.Rate,length(space)/d.Rate,length(space));
fmark = chirp(smts,2000,smts(end),2000,'linear',-90)'*.5;
stim = [];
[wave,wavefs]=audioread('BuzzNorm.wav');
% wave = wave-min(wave);
% wave = wave./max(wave);
% wave = wave.*2;
% wave = wave-mean(wave);

% a=audiorecorder(48000,8,2,1);
% a.TimerPeriod = 1;
% a.TimerFcn = @getaudio;
% a.StopFcn = @getaudio;

a = daq('directsound');
addinput(a,"Audio1",1:2,"Audio")
a.Rate = 48000;
a.ScansAvailableFcn = @getaudio;
a.ScansAvailableFcnCount = a.Rate/2;

buff = [];
sbuf = [];
% buflen = a.SampleRate*3;
%buflen = 2^16;
buflen = a.Rate*3;

SPECIES = 'Ae_ae';
TEMP = '';
HUMIDITY = '';
LUX = '';

STIMHOLDOFF = seconds(200);
ARMGATE = false;
LOGGING = false;
TTRIG = false;
STRIG = false;
SHOWUI = true;
lasttrig = datetime-STIMHOLDOFF;
lastarmpoll = datetime;

imaqreset
tv = videoinput("winvideo", 3, "MJPG_640x480");
tsrc = getselectedsource(tv);

tv.FramesPerTrigger = 1;
tv.TriggerRepeat = inf;
timg = getsnapshot(tv);
tlimg = timg;
ttimg = timg;

sv = videoinput("winvideo", 2, "MJPG_640x480");
ssrc = getselectedsource(sv);
sv.FramesPerTrigger = 1;
sv.TriggerRepeat = inf;
simg = getsnapshot(sv);
slimg = simg;
tsimg = simg;
f = uifigure('Position',[0 0 700 825],'CloseRequestFcn',@closecleanup,'Resize','off');

trigbtn = uibutton(f,'Position',[55 802 100 23],'Text','Manual Trigger','ButtonPushedFcn',@trig);
armbtn = uibutton(f,'Position',[2 802 50 23],'Text','Run','ButtonPushedFcn',@armcam,'BackgroundColor',[0 64/255 0],'FontColor','w');
stimdd = uidropdown(f,'Position',[157 802 75 23],'Items',{'180Hz','300Hz','450Hz','700Hz','None','Wave'},'ValueChangedFcn',@genstim);
duredit = uieditfield(f,"numeric",'Limits',[1 10000],'Position',[237 802 65 23],...
    'ValueChangedFcn',@genstim,'Value',250,'AllowEmpty',false,...
    'ValueDisplayFormat','%u ms','HorizontalAlignment','center');
armchk = uicheckbox(f,'Position',[305 802 150 23],'Text','Require Camera ARM','ValueChangedFcn',@armcheckcb);
hdbtn =  uibutton(f,'Position',[670 802 30 23],'Text','^','ButtonPushedFcn',@hide);

Lvaltext = uicontrol(f,'Style','text','Units','pixels');
Lvaltext.String = '';
Lvaltext.Position = [530-35 802 75 23];
Lvaltext.HorizontalAlignment = 'right';
Lvaltext.ForegroundColor = [0 64 0]./255;
Lvaltext.FontSize = 11;
Tvaltext = uicontrol(f,'Style','text','Units','pixels');
Tvaltext.String = '';
Tvaltext.Position = [605-35 802 40 23];
Tvaltext.HorizontalAlignment = 'right';
Tvaltext.ForegroundColor = 'r';
Tvaltext.FontSize = 11;
Hvaltext = uicontrol(f,'Style','text','Units','pixels');
Hvaltext.String = '';
Hvaltext.Position = [645-35 802 55 23];
Hvaltext.HorizontalAlignment = 'right';
Hvaltext.ForegroundColor = 'b';
Hvaltext.FontSize = 11;

topax = uiaxes(f,'InnerPosition',[0 400 500 400]);
hold(topax,'on');
topim = imagesc(topax,timg);
colormap(topax,'gray');
axis(topax,'off');
xlim(topax,[0 size(timg,2)]);
ylim(topax,[0 size(timg,1)]);
topax.Toolbar = [];
topax.Interactions = [];
topax.YDir = "reverse";
troi = images.roi.Circle(topax,'Center',[320 256],'Radius',40,'Color','c');
addlistener(troi,"MovingROI",@roifun);
tidx = troi.createMask;

sideax = uiaxes(f,'InnerPosition',[0 0 500 400]);
hold(sideax,'on');
sideim = imagesc(sideax,simg);
colormap(sideax,'gray');
axis(sideax,'off')
xlim(sideax,[0 size(simg,2)]);
ylim(sideax,[0 size(simg,1)]);
sideax.Toolbar = [];
sideax.Interactions = [];
sideax.YDir = 'reverse';
sroi = images.roi.Rectangle(sideax,'Position',[285 205 70 70],'Color','m');
addlistener(sroi,"MovingROI",@roifun);
sidx = sroi.createMask;

datax = uiaxes(f,'InnerPosition',[500 0 200 799.5],'Color','k');
hold(datax,'on')
tlin = plot(datax,1:15,nan(1,15),'Color','c');
slin = plot(datax,1:15,nan(1,15),'Color','m');
datax.Toolbar = [];
datax.Interactions = [];
ylim(datax,[-.01 0.1])
xlim(datax,[1 15])
yticklabels(datax,[]);
datax.HitTest = 'on';
tthresh = yline(datax,.01,'c--');
sthresh = yline(datax,.012,'m--');
datax.ButtonDownFcn = @setthresh;
hold(datax,'off');

setappdata(topim,'UpdatePreviewWindowFcn',@updatetop);
setappdata(sideim,'UpdatePreviewWindowFcn',@updateside);
preview(tv,topim);
preview(sv,sideim);
% record(a);
start(r,'continuous');
start(a,'continuous');
genstim();

    function hide(h,e)
        hands = {armbtn,trigbtn,stimdd,duredit,armchk,Lvaltext,Hvaltext,Tvaltext,hdbtn};
        pos = f.Position;
        % sc=get(0,'ScreenSize');
        shift = 0;
        if SHOWUI
            SHOWUI = false;
            datax.Visible = 'off';
            topim.Visible = 'off';
            sideim.Visible = 'off';
            f.WindowStyle='alwaysontop';
            h.Text ='v';
            pos(2) = pos(2)+800;
            pos(4)= pos(4)-800;
            shift = -800;
            f.Position = pos;
        else
            SHOWUI = true;
            datax.Visible = 'on';
            topim.Visible = 'on';
            sideim.Visible = 'on';
            f.WindowStyle='normal';
            h.Text ='^';
            if pos(2)-800<0
                pos(2)=0;
            else
               pos(2)=pos(2)-800;   
            end
            pos(4)= pos(4)+800;
            f.Position = pos;
            topax.InnerPosition=[0 400 500 400];
            sideax.InnerPosition=[0 0 500 400];
            datax.InnerPosition=[500 0 200 799.5];
            shift = 800;
        end
        for i = 1:length(hands)
            hands{i}.Position(2) = hands{i}.Position(2)+shift;
        end
    end
    
    function armcheckcb(h,e)
        if h.Value
            ARMGATE = true;
            STIMHOLDOFF = seconds(10);
        else
            ARMGATE = false;
            STIMHOLDOFF = seconds(200);
        end
    end

    function armcam(h,e)
        if strcmp(h.Text,'Run')
            h.Text = 'Stop';
            LOGGING = true;
            h.BackgroundColor = [1 0 0];
            lasttrig = datetime-seconds(STIMHOLDOFF);
        else
            h.Text = 'Run';
            LOGGING = false;
            h.BackgroundColor = [0 64/255 0];
        end
    end

    function trigeval()
        if ARMGATE || lasttrig+STIMHOLDOFF>datetime;return;end
        if LOGGING && (TTRIG && STRIG);trig;end
    end

    function trig(~,~)
        lasttrig = datetime;
        write(d,[stim;genppm(lasttrig)])
        % [data,tts]=readwrite(d,[stim;genppm(lasttrig)],'OutputFormat','Matrix');
        pause(1);
        stop(r);
        stop(a);
        drawnow
        if armchk.Value
            ARMGATE = true;
        end
        ts = char(lasttrig,'yyyyMMdd_HHmmss');
        ff = stimdd.Value;
        if strcmp(ff,'None')
            ff = '0Hz';
        elseif strcmp(ff,'Wave')
            ff = 'WAVE';
        end
        dd = [num2str(duredit.Value)];
        ll = num2str(LUX);
        tt = num2str(TEMP);
        rh = num2str(HUMIDITY);
        fn = [ts '_Ae_ae_' ll 'Lx_' tt 'C_' rh 'RH_' ff '_' dd 'ms.log'];
        out = {};
        out{1} = ['Time: ' char(lasttrig)];
        out{2} = 'Species: Aedes aegypti';
        out{3} = ['Ambient LUX: ' ll 'Lx'];
        out{4} = ['Temperature: ' tt 'C'];
        out{5} = ['Relative Humidity: ' rh '%'];
        out{6} = ['Stimulus Frequency: ' ff 'Hz'];
        out{7} = ['Stimulus Duration: ' dd 'ms'];
        micdata = buff;
        micsync = sbuf;
        % tstamps = linspace(1/a.SampleRate,length(buff)/a.SampleRate,length(buff))';
        tstamps = linspace(1/a.Rate,length(buff)/a.Rate,length(buff))';
        mtab = table(tstamps,micdata,micsync);
        data = daqdata;
        tts = linspace(1/r.Rate,size(data,1)/r.Rate,size(data,1))';
        dtab = table(tts,data(:,1),data(:,2),'VariableNames',{'tstamps','camtrigger','stimulus'});

        if LOGGING
            writetable(mtab,[fn(1:end-3) 'csv']);
            writetable(dtab,[fn(1:end-3) 'dat']);
            writelines(out,fn)
            imwrite(tsimg,[fn(1:end-3) 'side.jpeg']);
            imwrite(ttimg,[fn(1:end-3) 'top.jpeg']);
        else
            figure;
            tt=tiledlayout(1,3);
            nexttile
            plot(tts,data(:,1),'r');hold on
            plot(tts,data(:,2),'k')
            xlabel('time (s)')
            ylabel('amplitude (v)')
            nexttile
            plot(tstamps,micdata,'k');hold on
            plot(tstamps,micsync,'r');
            xlabel('time (s)')
            ylabel('amplitude (au)')
            box off
            nexttile
            % fr = linspace(1/a.SampleRate,a.SampleRate,length(micdata));
            fr = linspace(1/a.Rate,a.Rate,length(micdata));
            mag = abs(fft(micdata));
            plot(fr,mag,'k');
            xlim([0 1000]);
            box off
            xlabel('frequency (Hz)');
            ylabel('magnitude (au)');
            title(tt,fn(1:end-4),'interpreter','none');
            udata = struct;
            udata.MicTab = mtab;
            udata.DAQTab = dtab;
            udata.LogLines = out;
            udata.fn = fn(1:end-4);
            uicontrol('Style','pushbutton','String','Save','Position',[5 5 60 20],'Callback',@savefromfig,'UserData',udata)
        end
        % record(a);
        flush(r);
        start(r,'continuous');
        flush(a);
        start(a,'continuous');
    end

    function genstim(~,~)
        duredit.Enable = 'on';
        frq = stimdd.Value;
        dur = duredit.Value/1000;
        N = round(d.Rate*dur);
        if strcmp(frq,'None')
            stim = repmat([3,0],N,1);
        elseif strcmp(frq,'Wave')
            wv = wave;
            % wv = wv./max(wv);
            % wv = wv.*2;
            % wv = wv-mean(wv);
            duredit.Enable = 'off';
            stim = [repmat(3,size(wv)) wv];
        else
            frq = str2double(frq(1:end-2));
            ts = linspace(1/N,dur,N);
            audio = chirp(ts,frq,ts(end),frq,'linear',-90)';
            trig = double(audio>0).*3;
            stim = [trig audio];
        end
        ttt=linspace(1/d.Rate,size(stim,1)/d.Rate,size(stim,1));
        chp = chirp(ttt,2000,ttt(end),2000,'linear',-90);
        chp = chp'*.5;
        stim = [stim chp];
    end
    
    function ppm=genppm(dt)
        vec=dec2bin(convertTo(dt,'posixtime'),32)=='0';
        ppm = space;
        fppm = space;
        for i = vec
            ppm = [ppm;mark;space];
            fppm = [fppm;fmark; space];
            if i
                ppm = [ppm;space];
                fppm = [fppm;space];
            end
        end
        ppm = [ppm;mark;space];
        fppm = [fppm;fmark;space];
        ppm = [ppm zeros(size(ppm,1),1) fppm];
    end

    function getdaq(h,e)
        if h.NumScansAvailable>0
            tmp = read(h,h.NumScansAvailable,'OutputFormat','Matrix');
            daqdata = [daqdata;tmp(:,1:3)];
            if size(daqdata,1)>buflen
                daqdata = daqdata(end-(buflen-1):end,:);
            end
            if ARMGATE && (seconds(1)+lastarmpoll<datetime&&lasttrig+STIMHOLDOFF<datetime)
                dat = tmp(end,[3 4 5]);
                lastarmpoll = datetime;
                if all(dat>2)
                    ARMGATE = false;
                    lasttrig = datetime-STIMHOLDOFF+seconds(10);
                end
            end
        end
    end

    function getaudio(h,e)
        % tmp = getaudiodata(h);
        tmp = read(h,h.NumScansAvailable,'OutputFormat','Matrix');
        buff = [buff; tmp(:,1)];
        sbuf = [sbuf; tmp(:,2)];
        if length(buff)>buflen
            buff = buff(end-(buflen-1):end);
            sbuf = sbuf(end-(buflen-1):end);            
        end
    end

    function updatetop(obj,event,himage)
        tlimg = timg; %assign current preview image to old preview image
        timg = event.Data; %assign new preview image to current preview image
        df = imabsdiff(tlimg,timg);%calculate absolute difference between current and last frame
        val = mean(df(tidx))./255; %take the average absolute difference within the ROI defined by tidx
        if val>tthresh.Value;TTRIG = true;ttimg = timg;else;TTRIG=false;end %determine if value meets threshold criteria to trigger stimulus
        trigeval;
        if SHOWUI
            tlin.YData = [tlin.YData(2:end) val];%put current value of val onto the line in the GUI
            himage.CData = timg;%assign current image to image object in GUI
        end
    end

    function updateside(obj,event,himage)
        slimg = simg;
        simg = event.Data;
        df = imabsdiff(slimg,simg);
        val = mean(df(sidx))./255;
        if val>sthresh.Value;STRIG = true;tsimg = simg;else;STRIG=false;end
        trigeval;
        if SHOWUI
            slin.YData = [slin.YData(2:end) val];
            himage.CData = simg;  
        end        
    end

    function setthresh(h,e)
        val = e.IntersectionPoint(2);
        switch e.Button
            case 1
                tthresh.Value = val;
            case 3
                sthresh.Value = val;
        end        
    end

    function roifun(h,e)
        switch h
            case troi
                tidx = troi.createMask;
            case sroi
                sidx = sroi.createMask;
        end
    end    

    function savefromfig(h,~)
        dat = h.UserData;
        writelines(dat.LogLines,[dat.fn '.log']);
        writetable(dat.MicTab,[dat.fn '.csv']);
        writetable(dat.DAQTab,[dat.fn '.dat']);
    end

    function readtemphumidity(h,~)
        th = str2double(strsplit(readline(h),','));
        TEMP = round(th(2));
        HUMIDITY = round(th(1));
        LUX = round(th(3));
        Lvaltext.String = [num2str(LUX), ' LUX'];
        Tvaltext.String = [num2str(TEMP) ,'°C'];
        Hvaltext.String = [num2str(HUMIDITY) ,char(1642),'RH'];
    end

    function closecleanup(h,e)
        write(interlock,0);
        delete(interlock);
        stop(a);
        flush(a);
        delete(a);
        stop(d);
        flush(d);
        write(d,[0 0 0]);
        stop(r);
        delete(r);
        delete(h);
        delete(s);
        stop(tv);
        stop(sv);
    end
end
