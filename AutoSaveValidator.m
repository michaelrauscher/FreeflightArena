function AutoSaveValidator()
[configpath,~,~]=fileparts(mfilename('fullpath')); %path of this function so we can load/save config data here
cd(configpath);
settingsfile = fullfile(configpath,'autosavevalidator.set');
% uisettings = [];
if(isfile(settingsfile));load(settingsfile,'-mat');end

if isempty(uisettings)
    uisettings.lastfile = [];
    uisettings.visualize = true;
    uisettings.autosave = false;
    uisettings.autoadvance = true;
    uisettings.showtracks = true;
    uisettings.trackroi = 32;
    uisettings.zoom = 'full';
    uisettings.mode = 'auto';
end
if ~isfield(uisettings,'notestable')
    uisettings.notestable = cell2table(cell(0,2),'VariableNames',{'Filename','Notes'});  
end

f = uifigure('Position',[0 0 1920 1080],...
    'CloseRequestFcn',@closecleanup,...
    'WindowState','maximized',...  
    'AutoResizeChildren','off',...
    'SizeChangedFcn',@resize,...
    'KeyPressFcn',@keyshort);

%determine what theme we're using to set a few colors
themecol = 'k';
if (isprop(f,'Theme') & isprop(f.Theme,'Name')) & strcmp(f.Theme.Name,'Dark Theme')
    themecol = 'w';
end

%plot a line as a patch so we can control alpha post-hoc
lineAlphaFcn = @(ax,x,y,color,alpha,varargin) ...
    patch(ax,'XData',[x(:);nan],...
    'YData',[y(:);nan],...
    'EdgeColor',color,...
    'EdgeAlpha',alpha, ...
    varargin{:});

vrT = [];
vrS = [];

simg = zeros(512,640,1);
timg = simg;

[ftab,dtab,colwidth,editable] = getfiles();
cix = [];
filestbl = uitable(f,'Data',dtab,'Position',[0 0 1280 568]);
filestbl.ColumnWidth = colwidth;
filestbl.ColumnEditable = editable;
filestbl.DoubleClickedFcn = @tblcb;
filestbl.CellEditCallback = @notesave;
filestbl.Multiselect = 'off';

redstyle = uistyle('BackgroundColor',[1 0.6 0.6]);
greenstyle = uistyle('BackgroundColor',[0.6 1 0.6]);
bluestyle =uistyle('BackgroundColor',[173,216,230]./255);

nextbtn = uibutton(f,"Text","v","ButtonPushedFcn",@buttons);
prevbtn = uibutton(f,"Text","^","ButtonPushedFcn",@buttons);
savebtn = uibutton(f,"Text","Save","ButtonPushedFcn",@buttons);
delbtn = uibutton(f,"Text","Delete","ButtonPushedFcn",@buttons);

topax = uiaxes(f,'InnerPosition',[0 568 640 512]);
hold(topax,'on');
topim = imagesc(topax,timg,'ButtonDownFcn',@buttons);
colormap(topax,'gray');
axis(topax,'off');
xlim(topax,[0 size(timg,2)]);
ylim(topax,[0 size(timg,1)]);
topax.Toolbar = [];
topax.Interactions = [];

sideax = uiaxes(f,'InnerPosition',[640 568 640 512]);
hold(sideax,'on');
sideim = imagesc(sideax,simg,'ButtonDownFcn',@buttons);
colormap(sideax,'gray');
axis(sideax,'off')
xlim(sideax,[0 size(simg,2)]);
ylim(sideax,[0 size(simg,1)]);
sideax.Toolbar = [];
sideax.Interactions = [];

progax = uiaxes(f,'InnerPosition',[0 0 1280 100]);
hold(progax,'on');
xticklabels(progax,[]);
yticklabels(progax,[]);
marklin = plot(progax,nan,nan,themecol);
marklin.ButtonDownFcn = @buttons;
proglin = xline(progax,0,'-','Color',themecol);
progax.ButtonDownFcn = @buttons;
progax.Toolbar = [];
progax.Interactions = [];
yticks(progax,0:.5:1);
ylim(progax,[-.1 1.1]);
grid(progax,'on');
framewind = uieditfield(f,'Enable','off','HorizontalAlignment','center');

playpause = uibutton(f,'Text',char(9205),'FontSize',20,'ButtonPushedFcn',@buttons);
stopbtn = uibutton(f,'Text',char(9209),'FontSize',20,'ButtonPushedFcn',@buttons);
nextframe = uibutton(f,'Text','>','ButtonPushedFcn',@buttons);
prevframe = uibutton(f,'Text','<','ButtonPushedFcn',@buttons);
autosavechk = uicheckbox(f,'Text','Autosave','Value',uisettings.autosave);
vtimer = timer('ExecutionMode','fixedDelay',...
    'TimerFcn',@timercb,'Period',.01);

trx = [];
ctx = 0;

vischk = uicheckbox(f,'Text','Visualize','ValueChangedFcn',@buttons,'Value',uisettings.visualize);
advchk = uicheckbox(f,'Text','Autoadvance','ValueChangedFcn',@buttons,'Value',uisettings.autoadvance);
showtraxbtn = uicheckbox(f,'Text','Show Track','ValueChangedFcn',@buttons,'Value',uisettings.showtracks);

if ~isfield(uisettings,'trackroi')
    uisettings.trackroi = 64;
end
roibtn = uibutton(f,"Text",["ROI";string(uisettings.trackroi)+"x"+string(uisettings.trackroi)],...
    "ButtonPushedFcn",@buttons,'UserData',uisettings.trackroi);


switch uisettings.mode
    case 'auto'
        trkbtn = uibutton(f,"Text",["Track";"AUTO"],"ButtonPushedFcn",@buttons,'UserData','auto');
    case 'manual'
        trkbtn = uibutton(f,"Text",["Track";"MANUAL"],"ButtonPushedFcn",@buttons,'UserData','manual');
end
switch uisettings.zoom
    case 'full'
        zmbtn = uibutton(f,"Text",["Plot";"FULL"],"ButtonPushedFcn",@buttons,'UserData','full');
    case 'tight'
        zmbtn = uibutton(f,"Text",["Plot";"TIGHT"],"ButtonPushedFcn",@buttons,'UserData','tight');
    case 'zoom'
        zmbtn = uibutton(f,"Text",["Plot";"zoom"],"ButtonPushedFcn",@buttons,'UserData','zoom');
end

selstartbtn = uibutton(f,"Text","[","ButtonPushedFcn",@buttons);
selstopbtn = uibutton(f,"Text","]","ButtonPushedFcn",@buttons);
selresetbtn = uibutton(f,"Text","[]","ButtonPushedFcn",@buttons);
tdelselbtn = uibutton(f,"Text",["(top) Delete";"Selected"],"ButtonPushedFcn",@buttons);
sdelselbtn = uibutton(f,"Text",["(side) Delete";"Selected"],"ButtonPushedFcn",@buttons);

trax = uiaxes(f);
hold(trax,'on');
praxlin = xline(trax,0,'-','Color',themecol);
yyaxis(trax,'right');
selrgn = area(trax,[nan nan],[1 1],'FaceColor',[0 0 0],'FaceAlpha',.3,'EdgeColor','none','ButtonDownFcn',@buttons);
ylim(trax,[0 1]);
yyaxis(trax,'left');
trax.YAxis(1).Color = themecol;
trax.YAxis(2).Color = 'none';
ylabel(trax,'Position (px)');
xlabel(trax,'Frame (#)')
trax.Toolbar = [];
trax.Interactions = [];
trax.ButtonDownFcn = @buttons;

loading = false;
tracking = false;
vt = vision.PointTracker;

tbx = plot(topax,nan,nan,'r');
sbx = plot(sideax,nan,nan,'r');

tb = table('Size',[0,3],...
    'VariableTypes',...
    ["string","categorical","string"],...
    'VariableNames',{'Color','Sex','Notes'});
ttab=uitable(f,'Data',tb);
ttab.SelectionChangedFcn = @tselcb;
ttab.RowStriping = 'off';
ttab.ColumnEditable = [false true true];
ttab.ColumnWidth = {'fit','fit','auto'};

addtraxbtn = uibutton(f,"Text",["Add";"Track"],"ButtonPushedFcn",@buttons);
deltraxbtn = uibutton(f,"Text",["Delete";"Track"],"ButtonPushedFcn",@buttons);
tmd = [];
smd = [];

if ~isempty(ftab)
    fidx = 1;
    if ~isempty(uisettings.lastfile)
        fidx = find(strcmp(ftab.csvname,uisettings.lastfile));
        if isempty(fidx)
            fidx = 1;
        end
    end
    loadvid(fidx);
end

    function resize(h,e)
        wt = h.Position(3);
        ht = h.Position(4);
        vidwt = wt/3;
        vidht = 4/5 * vidwt;
        filestbl.OuterPosition = [0 ht-vidht-50 vidwt-50 vidht+50];
        tht=vidht+50;
        prevbtn.Position = [vidwt-50 ht-tht/4 50 tht/4];
        nextbtn.Position = [vidwt-50 ht-2*tht/4 50 tht/4];
        savebtn.Position = [vidwt-50 ht-3*tht/4 50 tht/4];
        delbtn.Position = [vidwt-50 ht-tht 50 tht/4];

        progax.InnerPosition = [vidwt+150 ht-vidht-50 vidwt*2-150 25];
        framewind.Position = progax.InnerPosition+[0 25 0 0];
        playpause.Position = [vidwt ht-vidht-50 50 50];
        stopbtn.Position = [vidwt+50 ht-vidht-50 50 50];
        nextframe.Position = [vidwt+100 ht-vidht-25 50 25];
        prevframe.Position = [vidwt+100 ht-vidht-50 50 25];
        
        topax.InnerPosition = [vidwt ht-vidht vidwt vidht];
        sideax.InnerPosition = [vidwt*2 ht-vidht vidwt vidht];
        trax.OuterPosition = [vidwt+60 10 vidwt*2-50 ht-vidht-90];
        ttab.OuterPosition = [50 0 vidwt-100 ht-vidht-50];
        addtraxbtn.Position = [0 (ht-vidht-50)/2 50 (ht-vidht-50)/2];
        deltraxbtn.Position = [0 0 50 (ht-vidht-50)/2];

        autosavechk.Position = [vidwt-40 ht-vidht-80 100 20];
        advchk.Position = [vidwt-40 ht-vidht-100 100 20];
        vischk.Position = [vidwt-40 ht-vidht-120 100 20];
        showtraxbtn.Position = [vidwt-40 ht-vidht-140 100 20];
        selstartbtn.Position = [vidwt-40 ht-vidht-170 20 20];
        selstopbtn.Position = [vidwt-15 ht-vidht-170 20 20];
        selresetbtn.Position = [vidwt+10 ht-vidht-170 30 20];
        tdelselbtn.Position = [vidwt-40 ht-vidht-215 80 40];
        sdelselbtn.Position = [vidwt-40 ht-vidht-255 80 40];

        roibtn.Position = [vidwt-40 170 80 70];
        trkbtn.Position = [vidwt-40 90 80 70];
        zmbtn.Position = [vidwt-40 10 80 70];
    end

    function run = isRunning()
        run = strcmp(vtimer.Running,'on');
    end

    function timercb(~,~)
        ix = proglin.Value;
        if ix + 1>vrT.numframes
            buttons(playpause,[]);
            return
        else
            setframe(ix+1);
        end
    end

    function track(pos,im,ix,mode)
        if im == topim
            bx = tbx;
            xln = trx(ix).txL;
            yln = trx(ix).tyL;
            sc = trx(ix).tht;
            img = timg;
            md = tmd;
        else
            bx = sbx;
            xln = trx(ix).sxL;
            yln = trx(ix).syL;
            sc = trx(ix).sht;
            img = simg;
            md = smd;
        end
        % img = im2gray(im.CData);
        set([trx.tpt],'Visible','off');
        set([trx.spt],'Visible','off');
        set([trx.tht],'Visible','off');
        set([trx.sht],'Visible','off');
        if showtraxbtn.Value;sc.Visible = 'on';end
        fix = proglin.Value;

        switch mode
            case 'manual'
                topim.CData = timg;
                sideim.CData = simg;
                xln.YData(fix)=pos(1);
                yln.YData(fix)=pos(2);
                sc.XData(fix)=pos(1);
                sc.YData(fix)=pos(2);
                tracking = false;
                if advchk.Value
                    timercb;
                else
                    setframe;
                end
            case 'auto'
                rgn = [pos(1)-24 pos(2)-24 48 48];
                img = imabsdiff(img,md);
                % points = detectMinEigenFeatures(img,'ROI',rgn);
                % sc.XData = points.Location(:,1);
                % sc.YData = points.Location(:,2);
                % release(vt);
                % initialize(vt,points.Location,img);
                % sc.Marker = "o";
                % sc.LineStyle = "none";
                % sc.XData = pos(:,1);
                % sc.YData = pos(:,2);
                release(vt);
                vt.BlockSize = [15 15];
                vt.NumPyramidLevels = 1;
                initialize(vt,pos,img);

                ctr = 0;
                while tracking
                    timercb;
                    fix = proglin.Value;
                    if im == topim
                        img = timg;
                        sideim.CData = simg;
                    else
                        img = simg;
                        topim.CData = timg;
                    end
                    pimg = imabsdiff(img,md);

                    if vischk.Value
                        im.CData = imfuse(img,pimg,'ColorChannels',[2 1 1]);
                    else
                        im.CData = img;
                    end
                    [points,validity] = vt(pimg);
                    rsz = roibtn.UserData;
                    rgn = [pos(1)-rsz/2 pos(2)-rsz/2 rsz rsz];
                    cn = bbox2points(rgn);
                    inpoly = inpolygon(points(:,1),points(:,2),cn(:,1),cn(:,2));
                    points = points(validity&inpoly,:);
                    if ~isempty(points)
                        % x = points(:,1);
                        % y = points(:,2);
                        % sc.XData = x;
                        % sc.YData = y;
                        bx.XData = cn([1:end 1],1);
                        bx.YData = cn([1:end 1],2);
                        pos = mean(points,1);
                        xln.YData(fix)=pos(1);
                        yln.YData(fix)=pos(2);
                        sc.XData(fix)=pos(1);
                        sc.YData(fix)=pos(2);
                        ctr = ctr+1;
                        if ctr==5
                            ctr = 0;
                            if (rgn(1)>0 && rgn(2)>0) &&...
                                    (rgn(1)+rgn(3)<size(pimg,2)) &&...
                                    (rgn(2)+rgn(4)<size(pimg,1))
                                mask = zeros(size(pimg));
                                mask = insertShape(mask,'filled-rectangle',rgn,'ShapeColor','white');
                                mask = mask(:,:,1)>0.5;
                                p = regionprops(mask,pimg,'WeightedCentroid');
                                pos = p.WeightedCentroid;
                                release(vt);
                                initialize(vt,pos,pimg);

                                % points = detectMinEigenFeatures(im2gray(img),'ROI',rgn);
                                % release(vt);
                                % initialize(vt,points.Location,img);
                            end
                        end
                    else
                        tracking = false;
                    end
                    drawnow limitrate;
                end
        end
        set([trx.tpt],'Visible','on');
        set([trx.spt],'Visible','on');
        if showtraxbtn.Value
            set([trx(ix).tht],'Visible','on');
            set([trx(ix).sht],'Visible','on');
        end
    end

    function buttons(h,e)
        if loading; return;end
        switch h
            case {topim,sideim}
                if height(ttab.Data)==0;return;end
                if tracking
                    tracking = false;
                    drawnow
                else
                    if height(ttab.Data)==1
                        ctx = 1;
                    elseif ctx==0
                        return;
                    end
                    alpha(h,.7)
                    tracking = true;
                    if e.Button==3
                        pos = [nan nan];
                        mode = 'manual';
                    else
                        pos = e.IntersectionPoint(1:2);
                        mode = trkbtn.UserData;
                    end
                    track(pos,h,ctx,mode);
                end
                alpha(h,1);
                setframe;
            case {progax,marklin,trax,selrgn}
                tracking = false;
                if isempty(vrT);return;end
                if e.Button == 2
                    selrgn.XData = [nan nan];
                else
                    val = e.IntersectionPoint(1);
                    val = round(val);
                    if val>progax.XLim(2)
                        val = progax.XLim(2);
                    elseif val<1
                        val = 1;
                    end
                    fix = proglin.Value;
                    if fix~=val && e.Button==3
                        selrgn.XData = [min([val fix]) max([val fix])];
                    end
                    setframe(val);
                end
            case roibtn
                val = h.UserData;
                vals = [16 32 64 128];
                ix = find(val==vals);
                if ix==length(vals)
                    ix = 1;
                else
                    ix = ix+1;
                end
                val = vals(ix);
                h.UserData = val;
                h.Text = ["ROI";string(val)+"x"+string(val)];
            case trkbtn
                if strcmp(h.UserData,'auto')
                    h.UserData = 'manual';
                    h.Text = ["Track";"MANUAL"];
                else
                    h.UserData = 'auto';
                    h.Text = ["Track";"AUTO"];
                end
            case zmbtn
                yyaxis(trax,'left');
                if strcmp(h.UserData,'full')
                    h.UserData = 'tight';
                    h.Text = ["Plot";"TIGHT"];
                    trax.XLimMode = 'auto';
                elseif strcmp(h.UserData,'tight')
                    h.UserData = 'zoom';
                    h.Text = ["Plot";"ZOOM"];
                    trax.XLimMode = 'manual';
                    trax.XLim = [proglin.Value-20 proglin.Value+20];
                else
                    h.UserData = 'full';
                    h.Text = ["Plot";"FULL"];
                    trax.XLimMode = 'manual';
                    trax.XLim = [1 vrS.numframes];
                end
            case vischk
                if ~(isRunning || tracking)
                    setframe;
                end
            case showtraxbtn
                if isempty(trx);return;end
                set([trx.sht;trx.tht],'Visible','off');
                if h.Value && ctx>0                    
                    set([trx(ctx).sht;trx(ctx).tht],'Visible','on');
                end
            case playpause
                if tracking;tracking = false;return;end
                if strcmp(h.Text,char(9205))
                    if ~isempty(trx)
                        set([trx.tpt],'Visible','off');
                        set([trx.spt],'Visible','off');
                    end
                    h.Text = '||';
                    start(vtimer);
                else
                    if ~isempty(trx)
                        set([trx.tpt],'Position',[-1 -1]);
                        set([trx.spt],'Position',[-1 -1]);
                        set([trx.tpt],'Visible','on');
                        set([trx.spt],'Visible','on');
                    end
                    h.Text = char(9205);
                    stop(vtimer);
                    setframe;
                end
            case stopbtn
                if tracking;tracking = false;return;end
                if isRunning
                    buttons(playpause);
                end
                setframe(1);
            case nextframe
                setframe(proglin.Value+1);
            case prevframe
                setframe(proglin.Value-1);
            case addtraxbtn
                addtrax;
                h = height(ttab.Data);
                w = width(ttab.Data);
                ttab.Selection = [h 2;h 3];
                ctx = h;
            case deltraxbtn
                ix = ttab.Selection;
                if isempty(ix) || ~all(ix(:,1)==ix(1));return;end
                ix = ix(1);
                deltrax(ix);
                setframe;                
            case selstartbtn
                selrgn.XData(1)=proglin.Value;
                if isnan(selrgn.XData(2));selrgn.XData(2)=vrS.numframes;end
            case selstopbtn
                selrgn.XData(2)=proglin.Value;
                if isnan(selrgn.XData(1));selrgn.XData(1)=1;end
            case selresetbtn
                selrgn.XData = [nan nan];
            case tdelselbtn
                if ~(isRunning || all(isnan(selrgn.XData)))
                    ix = ttab.Selection;
                    if isempty(ix) || ~all(ix(:,1)==ix(1));return;end
                    ix = ix(1);
                    rgn = selrgn.XData(1):selrgn.XData(2);
                    trx(ix).txL.YData(rgn)=nan;
                    trx(ix).tyL.YData(rgn)=nan;
                    trx(ix).tht.XData(rgn)=nan;
                    trx(ix).tht.YData(rgn)=nan;
                    setframe;
                end
            case sdelselbtn
                if ~(isRunning || all(isnan(selrgn.XData)))
                    ix = ttab.Selection;
                    if isempty(ix) || ~all(ix(:,1)==ix(1));return;end
                    ix = ix(1);
                    rgn = selrgn.XData(1):selrgn.XData(2);
                    trx(ix).sxL.YData(rgn)=nan;
                    trx(ix).syL.YData(rgn)=nan;
                    trx(ix).sht.XData(rgn)=nan;
                    trx(ix).sht.YData(rgn)=nan;
                    setframe;
                end
            case prevbtn
                if cix<=1;return;end
                loadvid(cix-1);
            case nextbtn
                if cix>=height(ftab);return;end
                loadvid(cix+1);
            case savebtn
                savefile
            case delbtn
                tf = ftab.savename{cix};
                if ~isfile(tf);return;end
                val=questdlg('Delete File?','Delete File','Yes','No','No');
                if strcmp(val,'No');return;end
                delete(tf);
                updatefdisp;
        end
    end

    function ptcb(h,e)
        track = false;
        if strcmp(e.EventName,'ROIClicked')            
            h.UserData = h.UserData+1;
            if h.UserData>=2
                track = true;
                h.UserData = 0;
            end
        else
            h.UserData = 0;
        end
        pos = h.Position;
        fix = proglin.Value;
        
        side = 1;
        ix = find([trx.spt]==h);
        if isempty(ix)
            side = 2;
            ix = find([trx.tpt]==h);
        end

        if track
            n = [];
            n.IntersectionPoint = pos;
            n.Button = 1;
            if side == 2
                buttons(topim,n);
            else
                buttons(sideim,n);
            end
        else
            if side == 2
                trx(ix).txL.YData(fix)=pos(1);
                trx(ix).tyL.YData(fix)=pos(2);
            else
                trx(ix).sxL.YData(fix)=pos(1);
                trx(ix).syL.YData(fix)=pos(2);
            end
            if ctx~=ix
                ctx = ix;
                ttab.Selection = [ix 2;ix 3];
            end
            setframe;
        end
    end

    function tselcb(h,e)    
        if loading; return;end
        ctx = 0;
        sel = e.Selection;
        if ~isempty(sel)
            ctx = min(sel(:,1));
            h.Selection(h.Selection(:,1)~=ctx,:)=[];
            % h.Selection = [ctx 2; ctx 3];
            tdx = false(1,length(trx));
            tdx(ctx)=true;
            set([trx(tdx).sxL trx(tdx).syL trx(tdx).txL trx(tdx).tyL],...
                'EdgeAlpha',1);
            if showtraxbtn.Value
                set([trx(tdx).tht;trx(tdx).sht],'Visible','on');
            end
            tdx = ~tdx;
            set([trx(tdx).sxL trx(tdx).syL trx(tdx).txL trx(tdx).tyL],...
                'EdgeAlpha',.3);
            if showtraxbtn.Value
                set([trx(tdx).tht;trx(tdx).sht],'Visible','off');
            else
                set([trx.tht;trx.sht],'Visible','off');
            end
            if ~isRunning;setframe;end
        else
            sbx.XData = nan;
            sbx.YData = nan;
            tbx.XData = nan;
            tbx.YData = nan;
            set([trx.tht;trx.sht],'Visible','off');
        end
    end

    function addtrax(lt)
        ix = height(ttab.Data)+1;        
        st = [];
        yyaxis(trax,'left');
        if nargin<1
            sx = categorical("Undefined",["Undefined","Male","Female"]);
            ttab.Data = [ttab.Data; table("",sx,"",'VariableNames',ttab.Data.Properties.VariableNames)];
            ttab.RowName = string(1:ix)';
            col = lines(ix);
            col = col(end,:);
            n = vrS.numframes;
            st.Color = col;
            st.sxL = lineAlphaFcn(trax,1:n,nan(size(1:n)),col,.6);
            st.syL = lineAlphaFcn(trax,1:n,nan(size(1:n)),col,.6,'LineStyle',':');
            st.txL = lineAlphaFcn(trax,1:n,nan(size(1:n)),col,.6,'LineWidth',2);
            st.tyL = lineAlphaFcn(trax,1:n,nan(size(1:n)),col,.6,'LineStyle',':','LineWidth',2);
            st.tht = scatter(topax,nan(size(1:n)),nan(size(1:n)),50,col,'Visible','off','MarkerEdgeAlpha',.5,'HitTest','off','PickableParts','none');
            st.sht = scatter(sideax,nan(size(1:n)),nan(size(1:n)),50,col,'Visible','off','MarkerEdgeAlpha',.5,'HitTest','off','PickableParts','none');
        else
            ttab.Data = [ttab.Data; table("",lt.Sex,lt.Note,'VariableNames',ttab.Data.Properties.VariableNames)];
            ttab.RowName = string(1:ix)';
            col = lt.Color;
            n = vrS.numframes;
            st.Color = col;
            st.sxL = lineAlphaFcn(trax,1:n,lt.SPos(:,1),col,.6);
            st.syL = lineAlphaFcn(trax,1:n,lt.SPos(:,2),col,.6,'LineStyle',':');
            st.txL = lineAlphaFcn(trax,1:n,lt.TPos(:,1),col,.6,'LineWidth',2);
            st.tyL = lineAlphaFcn(trax,1:n,lt.TPos(:,2),col,.6,'LineWidth',2,'LineStyle',':');
            st.tht = scatter(topax,lt.TPos(:,1),lt.TPos(:,2),50,col,'Visible','off','MarkerEdgeAlpha',.5,'HitTest','off','PickableParts','none');
            st.sht = scatter(sideax,lt.SPos(:,1),lt.SPos(:,2),50,col,'Visible','off','MarkerEdgeAlpha',.5,'HitTest','off','PickableParts','none');
        end

        st.spt = images.roi.Point(sideax,'Position',[-1 -1],'Color',col,'ContextMenu',[],'UserData',0);
        addlistener(st.spt,'ROIClicked',@ptcb);
        addlistener(st.spt,'MovingROI',@ptcb);
        addlistener(st.spt,'ROIMoved',@ptcb);
        
        st.tpt = images.roi.Point(topax,'Position',[-1 -1],'Color',col,'ContextMenu',[],'UserData',0);
        addlistener(st.tpt,'ROIClicked',@ptcb);
        addlistener(st.tpt,'MovingROI',@ptcb);
        addlistener(st.tpt,'ROIMoved',@ptcb);

        trx = [trx;st];

        s = uistyle('BackgroundColor',col);
        addStyle(ttab,s,"cell",[ix 1]);
        restackhandles;
    end

    function restackhandles()
        yyaxis(trax,'left');
        for i = 1:length(trx)
            bringToFront(trx(i).spt);
            bringToFront(trx(i).tpt);
        end
        hand = get(topax,'Children');
        idx = hand==tbx;
        hand = [hand(idx); hand(~idx)];
        topax.Children = hand;
        hand = get(sideax,'Children');
        idx = hand==sbx;
        hand = [hand(idx); hand(~idx)];
        sideax.Children = hand;        
    end

    function deltrax(idx)
        if nargin<1
            idx = 1:height(ttab.Data);
        end
        for ix = idx(:)'
            delete(trx(ix).sxL);
            delete(trx(ix).syL);
            delete(trx(ix).txL);
            delete(trx(ix).tyL);
            delete(trx(ix).spt);
            delete(trx(ix).tpt);
            delete(trx(ix).sht);
            delete(trx(ix).tht);
        end
        ttab.Data(idx,:)=[];
        trx(idx)=[];
        if ~isempty(trx)
            for i = 1:length(trx)
                s = uistyle('BackgroundColor',trx(i).Color);
                addStyle(ttab,s,"cell",[i 1]);
            end
        end
        ctx = 0;
    end

    function setframe(i)
        if nargin<1
            i = proglin.Value;
        elseif i>vrS.numframes
            if isRunning;buttons(playpause);end
            if tracking;tracking=false;end
            i=vrS.numframes;
        elseif i<1
            i=1;
        end
        timg = im2gray(read(vrT,i));
        simg = im2gray(read(vrS,i));
        framewind.Value = "Frame "+string(i)+" of "+string(vrS.numframes);
        if strcmp(zmbtn.UserData,'zoom')
            trax.XLim = [i-20 i+20];
        end
        sbx.XData = nan;
        sbx.YData = nan;
        tbx.XData = nan;
        tbx.YData = nan;
        if tracking
            proglin.Value = i;
            praxlin.Value = i;
        else
            if vischk.Value
                pimg = imabsdiff(timg,tmd);
                topim.CData = imfuse(timg,pimg,'ColorChannels',[2 1 1]);
                pimg = imabsdiff(simg,smd);
                sideim.CData = imfuse(simg,pimg,'ColorChannels',[2 1 1]);
            else
                topim.CData = timg;
                sideim.CData = simg;
            end
            proglin.Value = i;
            praxlin.Value = i;

            if ~isRunning
                for ix = 1:length(trx)
                    pos = trx(ix).sxL.YData(i);
                    pos(2) = trx(ix).syL.YData(i);
                    if ix == ctx
                        sbx.XData = pos(1)+[-32 32 32 -32 -32];
                        sbx.YData = pos(2)+[32 32 -32 -32 32];
                    end
                    pos(isnan(pos))=-1;
                    trx(ix).spt.Position = pos;

                    pos = trx(ix).txL.YData(i);
                    pos(2) = trx(ix).tyL.YData(i);
                    if ix ==ctx
                        tbx.XData = pos(1)+[-32 32 32 -32 -32];
                        tbx.YData = pos(2)+[32 32 -32 -32 32];
                    end
                    pos(isnan(pos))=-1;
                    trx(ix).tpt.Position = pos;
                end
            end
            drawnow limitrate
        end
    end

    function notesave(h,e)
        if isempty(e.Indices);return;end
        [~,bname]=fileparts(ftab.csvname{e.Indices(1)});
        bix=find(strcmp(uisettings.notestable.Filename,bname));
        uisettings.notestable.Notes(bix) = strtrim(e.NewData);
        sn = ftab.savename{e.Indices(1)};
        if isfile(sn)
            sd = matfile(sn,'Writable',true);
            dd = sd.data;
            dd.note = char(strtrim(e.NewData));
            sd.data = dd;
        end
    end

    function tblcb(h,e)
        if loading; return;end
        if cix==h.Selection(1)|h.Selection(2)==width(h.Data);return;end
        filestbl.Enable = 'off';
        loadvid(h.Selection(1));
        filestbl.Enable = 'on';
    end

    function updatefdisp()
        rix = [];
        gix = [];
        for i = 1:height(ftab)
            val = isfile(ftab.savename(i));
            ftab.issave(i) = val;
            if val
                gix = [gix;i width(filestbl.Data)-1];
            else
                rix = [rix;i width(filestbl.Data)-1];
            end
        end
        removeStyle(filestbl)
        addStyle(filestbl,bluestyle,'row',cix);
        scroll(filestbl,'row',cix);
        if ~isempty(rix)
            addStyle(filestbl,redstyle,'cell',rix);
        end
        if ~isempty(gix)
            addStyle(filestbl,greenstyle,'cell',gix);
        end
    end

    function saveuisettings()
        if isfield(uisettings,'notestable')
            ttbl = uisettings.notestable;
        else
            ttbl = cell2table(cell(0,2),'VariableNames',{'Filename','Notes'});
        end
        uisettings = [];
        if ~isempty(cix)
            uisettings.lastfile = ftab.csvname{cix};
        else
            uisettings.lastfile = [];
        end
        uisettings.autosave = autosavechk.Value;
        uisettings.autoadvance = advchk.Value;
        uisettings.showtracks = showtraxbtn.Value;
        uisettings.visualize = vischk.Value;
        uisettings.trackroi = roibtn.UserData;
        uisettings.zoom = zmbtn.UserData;
        uisettings.mode = trkbtn.UserData;
        uisettings.notestable = ttbl;
        save(settingsfile,'uisettings');
    end

    function savefile()
        data = [];     
        if ~isempty(trx)
            track = [];
            for i = 1:length(trx)
                tt = [];
                tt.Color = trx(i).Color;
                x = trx(i).sxL.YData(1:end-1);
                y = trx(i).syL.YData(1:end-1);
                tt.Sex = ttab.Data.Sex(i);
                tt.Note = ttab.Data.Notes(i);
                tt.SPos = [x(:) y(:)];
                x = trx(i).txL.YData(1:end-1);
                y = trx(i).tyL.YData(1:end-1);
                tt.TPos = [x(:) y(:)];
                track = [track;tt];
            end
            data.track = track;
        end
        [~,basename]=fileparts(ftab.csvname{cix});
        data.basename=basename;
        data.note = filestbl.Data.Notes{cix};
        save(ftab.savename{cix},'data');
        updatefdisp;
    end

    function loadvid(ix)
        if isRunning
            buttons(stopbtn);
        end
        loading = true;
        if autosavechk.Value && ~isempty(cix)
            savefile;
        end
        cix = ix;
        updatefdisp;
        deltrax;

        vrT = VideoReader(ftab.topcam{ix});
        tavg = ftab.topcam{ix};
        tavg = string(extractBefore(tavg,'.'))+"_avg.png";
        
        if isfile(tavg)
            tmd=imread(tavg);
            tmd=im2gray(tmd);
            tmd = cast(tmd,class(read(vrT,1)));
        else
            tmd = zeros(vrT.Height,vrT.Width);
            for i = 1:vrT.numframes
                tmd = tmd+double(im2gray(read(vrT,i)));
            end
            tmd = tmd./vrT.numframes;
            tmd = cast(tmd,class(read(vrT,1)));
            imwrite(tmd,tavg);
        end

        topim.CData = read(vrT,1);
        topax.YDir = 'reverse';
        topax.XLim = [0 vrT.Width];
        topax.YLim = [0 vrT.Height];

        vrS = VideoReader(ftab.sidecam{ix});
        savg = ftab.sidecam{ix};
        savg = string(extractBefore(savg,'.'))+"_avg.png";

        if isfile(savg)
            smd=imread(savg);
            smd=im2gray(smd);
            smd = cast(smd,class(read(vrS,1)));
        else
            smd = zeros(vrS.Height,vrS.Width);
            for i = 1:vrS.numframes
                smd = smd+double(im2gray(read(vrS,i)));
            end
            smd = smd./vrS.numframes;
            smd = cast(smd,class(read(vrS,1)));
            imwrite(smd,savg);
        end

        sideim.CData = read(vrS,1);
        sideax.YDir = 'reverse';
        sideax.XLim = [0 vrS.Width];
        sideax.YLim = [0 vrS.Height];

        trig = fastecMarkerReader([ftab.topcam{ix}(1:end-4) '.xml'],6);
        try
            sg = find((diff(trig))==1);
            if length(sg)>32
                tbn=diff(sg(end-32:end))<20;
                tdt=datetime(bin2dec((num2str(tbn(:)'))),'ConvertFrom','posixtime');
                if abs(tdt-filestbl.Data{ix,1})<seconds(120)
                    trig(sg(end-32):end)=0;
                end
            end
        catch
            warning('Problem parsing metadata PPM date code');
        end

        progax.XLim = [1 vrT.NumFrames];
        trax.XLim = [1 vrT.NumFrames];
        trax.YDir = 'reverse';
        marklin.XData = progax.XLim(1):progax.XLim(2);
        marklin.YData = trig;
        proglin.Value = 1;  
        praxlin.Value = 1;

        
        if isfile(ftab.savename{cix})
            data = [];
            load(ftab.savename{cix});
            if isfield(data,'track')
                for i = 1:length(data.track)
                    addtrax(data.track(i));
                end
            end
        end
        setframe(1);
        loading = false;
    end

    function closecleanup(~,~)
        try
            saveuisettings
        catch
            warning('Problem saving UI settings -- settings not saved')
        end
        if autosavechk.Value && ~isempty(cix)
            savefile;
        end
        delete(f);
    end

    function [fstab, dtab,columnwidth, editable] = getfiles()
        tfiles = dir('**/*Ae_ae*.csv');
        [~,six]=sort({tfiles.name});
        tfiles = tfiles(six);
        csvname = {};
        savename = {};
        topcam = {};
        sidecam = {};

        is = [];
        ts = [];
        sp = {};
        lx = [];
        tp = [];
        rh = [];
        sf = [];
        sd = [];
        nt = [];

        for i = 1:length(tfiles)
            cname = tfiles(i).name;
            bname = cname(1:end-4);
            if ~isfile([fullfile(tfiles(i).folder,bname) '.log']);continue;end
            fold = split(tfiles(i).folder,filesep);
            fold = fold{end};
            if ~strcmp(fold,cname(1:end-4));continue;end
            topfile = dir([tfiles(i).folder filesep 'TOPCAM*.avi']);
            if isempty(topfile)|length(topfile)>1;continue;end
            ttemp = fullfile(topfile.folder,topfile.name);
            if ~isfile([ttemp(1:end-4) '.pm']) && ~isfile([ttemp(1:end-4) '.xml']);continue;end

            sidefile = dir([tfiles(i).folder filesep 'SIDECAM*.avi']);
            if isempty(sidefile)|length(sidefile)>1;continue;end
            stemp = fullfile(sidefile.folder,sidefile.name);
            if ~isfile([stemp(1:end-4) '.pm']) && ~isfile([stemp(1:end-4) '.xml']);continue;end

            topcam{end+1} = ttemp;
            sidecam{end+1} = stemp;
            csvname{end+1}=fullfile(tfiles(i).folder,cname);
            savename{end+1}=[csvname{end}(1:end-4) '_TRACK.mat'];
            
            is = [is;isfile(savename{end})];
            
            bix = find(strcmp(uisettings.notestable.Filename,bname));
            if isempty(bix)
                if is(end)
                    mm=matfile(savename{end});
                    mm = mm.data;
                    note = string(mm.note);
                else
                    note = "";
                end
                uisettings.notestable = [uisettings.notestable;...
                    cell2table({bname,note},'VariableNames',{'Filename','Notes'})];
            else
                note = string(uisettings.notestable.Notes{bix(1)});
            end

            tt = "";
            if contains(bname,'Ae_ae')
                tt = "Aedes aegypti";
            end
            sp = [sp;tt];

            uix=strfind(bname,'_');
            if length(uix(1):uix(2))==8
                tts = datetime(bname(1:uix(2)-1),'InputFormat','yyyyMMdd_HHmmss');
            else
                tts = datetime(bname(1:uix(2)-1),'InputFormat','yyyyMMdd_HHmss');
            end
            ts = [ts;tts];

            spl = strsplit(bname,'_');
            haslux = false;
            for j = spl(:)'
                if endsWith(j,'Lx')
                    lx = [lx;string(j)];
                    haslux = true;
                elseif endsWith(j,'C')
                    tp = [tp;string(j)];
                elseif endsWith(j,'RH')
                    rh = [rh;string(strrep(j,'RH','%'))];
                elseif endsWith(j,'Hz') || strcmp(j,'WAVE')
                    sf = [sf;string(j)];
                elseif endsWith(j,'ms')
                    sd = [sd;string(j)];
                end
            end
            
            % logname = [csvname{end}(1:end-4) '.log'];
            % lines = readlines(logname);
            % haslux = false;
            % for j = 1:length(lines)
            %     lin = lines{j};
            %     dtype = extractBefore(lin,':');
            %     data = strip(extractAfter(lin,':'));
            %     switch dtype
            %         case 'Time'                     
            %             ts = [ts; datetime(data)];
            %         case 'Species'
            %             sp= [sp; {data}];
            %         case 'Ambient LUX'
            %             val = extractBefore(data,'Lx');
            %             % lx = [lx; str2double(val)];
            %             lx = [lx;string(val) + "Lx"];
            %             haslux = true;
            %         case 'Temperature'
            %             val = extractBefore(data,'C');
            %             % tp = [tp; str2double(val)];
            %             tp = [tp; string(val)+"C"];
            %         case 'Relative Humidity'
            %             val = extractBefore(data,'%');
            %             % rh = [rh; str2double(val)];
            %             rh = [rh;string(val)+"%"];
            %         case 'Stimulus Frequency'
            %             val = extractBefore(data,'Hz');
            %             % sf = [sf; str2double(val)];
            %             sf = [sf; string(val)+"Hz"];
            %         case 'Stimulus Duration'
            %             val = extractBefore(data,'ms');
            %             % sd = [sd; str2double(val)];
            %             sd = [sd;string(val)+"ms"];
            %     end
            % end

            if ~haslux
                lx = [lx; "-"];
            end

            nt = [nt; note];
        end
        csvname = csvname';
        topcam = topcam';
        sidecam = sidecam';
        savename = savename';
        issave = is(:);
        fstab = table(csvname,savename,issave,topcam,sidecam);        
        
        is = repmat("",size(rh));
        if length(unique(sp))>1
            dtab = table(sp,ts,sf,sd,lx,tp,rh,is,nt);
            dtab.Properties.VariableNames = {'Species',...
                'Time',...
                'Freq',...
                'Dur'...
                'LUX ',...
                'T'...,
                'RH',...
                '*',...
                'Notes'};
            editable = logical([0 0 0 0 0 0 0 0 1]);
            columnwidth = {'fit','fit','fit','fit','fit','fit','fit','fit','auto'};
        else
            dtab = table(ts,sf,sd,lx,tp,rh,is,nt);
            dtab.Properties.VariableNames = {...
                'Time',...
                'Freq',...
                'Dur'...
                'LUX ',...
                'T'...,
                'RH',...
                '*',...
                'Notes'};
            editable = logical([0 0 0 0 0 0 0 1]);
            columnwidth = {'fit','fit','fit','fit','fit','fit','fit','auto'};
        end
    end

    function keyshort(h,e)
        if loading;return;end
        switch e.Key
            case {'rightarrow','d'}
                buttons(nextframe);
            case {'leftarrow','a'}
                buttons(prevframe);
            % case 'uparrow'
            %     if isempty(trx);return;end
            %     if ctx==0
            %         ctx = length(trx);
            %     elseif ctx>1
            %         ctx = ctx-1;
            %     end
            %     ttab.Selection = [ctx 1];
            % case 'downarrow'
            %     if isempty(trx);return;end
            %     if ctx==0
            %         ctx = 1;
            %     elseif ctx<length(trx)
            %         ctx = ctx+1;
            %     end
            %     ttab.Selection = [ctx 1];
            case 's'                
                if contains(e.Modifier,'control')
                    buttons(savebtn);
                end
            case 't'
                showtraxbtn.Value = ~showtraxbtn.Value;
                buttons(showtraxbtn);
            case 'e'
                advchk.Value = ~advchk.Value;
            case 'space'
                if tracking
                    tracking=false;
                else
                    buttons(playpause);
                end
            case 'r'
                buttons(roibtn);
            case 'z'
                buttons(zmbtn)
            case 'm'
                buttons(trkbtn)
            case 'n'
                if contains(e.Modifier,'control')
                    buttons(addtraxbtn);
                end
            case 'v'
                vischk.Value = ~vischk.Value;
                buttons(vischk)
        end
    end
end