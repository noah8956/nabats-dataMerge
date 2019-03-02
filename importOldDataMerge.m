clear all
close all

    % Read, match, merge, clean, average, and convert units for NABATS data. 
    % Series1 = data from 1959 - 1999
    % Series2 = 2000 - present. 
    % Series3 = 1959 - present
    % Merge Version 1 -- March 1, 2019
    % noahw@uri.edu

%% parameters
    mondayBuffer = days(4); % days after monday that counts will be matched to physical data
    mergeVersion = 1;
    note = 'code at ';
%     latestDay = series2phytoAvgDel.DATE(end);

%% load the old phytoplankton data
    load series1phyto
    names=fieldnames(series1phyto);

%% convert sereis1 merged csv to matlab table, add the names -- replace this with better import function
    for i = 2:length(names)
        convertCSV(i,:)=series1phyto.(names{i});
    end
    convertCSV=convertCSV';

    mergedTable = array2table(convertCSV);

    mergedTable.Properties.VariableNames = names;
    swetch=series1phyto.(names{1})';
    swetch=cellstr(swetch);
    % mergedTable(:,1)=[];

    mergedTable.DATE=datetime(series1phyto.DATE);
    mergedTable(1:2,:)=[];

    series1phyto=mergedTable;

    replength=1995;


%% 'simple import' series1 -- load the series1 physical and nutrient data ie. (simple =single column)
    fo = 'simpleImport';
    foDir = dir(fo);
    remD=[foDir.isdir];
    foDir(remD)=[];
    for i = 1:length(foDir)
    foFieldNames{i,1} = cellstr(foDir(i).name(1:3));
    end

    series1physical = table;

%% import series1 simple datasets -- loop
    for idx = 1:length(foDir)
       filename = [fo,'/',foDir(idx).name];
       series1imp = simpleImport(filename,1,inf,idx,foFieldNames);
       if idx == 1
            series1physical = series1imp(1:replength,:);
       else
       series1physical = [series1physical series1imp(1:replength,(foFieldNames{idx}))];
    %       series1 = [series1 series1imp(1:replength,['SampleDate',num2str(idx)]) series1imp(1:replength,(foFieldNames{idx}))];
       end
    end

%% load series1 salinity
    load salinity
    series1physical = [series1physical Salinity(1:replength,2:4)];

%% load series1 light
    load SecchiIrradiance.mat
    series1physical = [series1physical SecchiIrradiance(1:replength,2:end)];

%% load series1 temp
    load temp
    series1physical = [series1physical temp(1:replength,2:end)];

%% clean series1 data
    series1physical = standardizeMissing(series1physical,-999);
    series1physical([1:3],:) = [];

%% Series1/Series2 Name Match -- Remove the unmatched phytoplankton names (fuzzy/exact match in file matchDataSeries1Series2.m)
    load namesRemove
    findEmptyNames = find(cellfun(@isempty,namesRemove(:,2)));
    namesOldRemove = names(findEmptyNames);
    namesNew = namesRemove(:,2); namesNew(findEmptyNames)=[];
    namesOld = names; 
    namesOld(findEmptyNames)=[];
    for i = 1:length(namesOldRemove)
       series1phyto.(namesOldRemove{i})=[]; 
    end

%% load the series2 phyto data as a table, fix the dates
    fid='/Users/noahwalcutt/Documents/MatLab/homework/nabat/newDataAll/nabat1999to2018.csv';
    series2phyto = importNewData(fid);
    series2Names = fieldnames(series2phyto);
    series2phyto.DATE(1:50)=series2phyto.DATE(1:50) + years(1900);
    series2phyto.DATE(130:end)=series2phyto.DATE(130:end) + years(2000);

%% Divide all the series2 phytoplankton conc by 1000 to convert to mL
    k=1;
    for i = 4:length(series2Names)
        try
        series2phyto.(series2Names{i}) = series2phyto.(series2Names{i}) ./1000;
        catch
            k=k+1;
        end
    end

%% Find and average the double phyto count days for series 2, compute std, idx 2535 = day when they started doing two counts per day 09/03/2008
    [~, iUniquePhytoDate, ~] = unique(datenum(series2phyto.DATE),'last');
    series2phytoDate = series2phyto.DATE; series2phytoDate(iUniquePhytoDate)=[];
    series2phytoDateDoubleIDX = 1:length(series2phyto.DATE); series2phytoDateDoubleIDX(iUniquePhytoDate)=[];
    series2phytoDateDoubleIDX1 = series2phytoDateDoubleIDX;
    series2phytoDateDoubleIDX2 = series2phytoDateDoubleIDX+1;

    series2phytoAvg = series2phyto;
    for i = 4:length(series2Names)
        try
        series2phytoAvg{series2phytoDateDoubleIDX1,i} = nanmean([series2phytoAvg{series2phytoDateDoubleIDX1,i}, series2phytoAvg{series2phytoDateDoubleIDX2,i}],2);
        catch
            series2phytoAvgFail{i} = series2Names{i};
        end

    end

    series2phytoAvgDel = series2phytoAvg;
    series2phytoAvgDel(series2phytoDateDoubleIDX2,:)=[]; % delete the duplicate days

    % Fix some dates in the series2 data
        series2phytoAvgDel{987,1} = series2phytoAvgDel{987,1} - years(1);
        series2phytoAvgDel{995,1} = series2phytoAvgDel{995,1} + years(1);

%% load the series2 physical and nutrient data added March 2, 2019
load series2tempSal 
load series2chl 
load series2NitrogenPhosphate 
load series2Silica 

%% Create a continuous set of Mondays for series2 mapping 
            
    % create a vector of continuous mondays
            latestDay = series2phytoAvgDel.DATE(end);
            series3mondays = series2phytoAvgDel.DATE(1):caldays(7):latestDay;
            LOWER = days(1);
            UPPER = mondayBuffer;
            
%% SERIES2 TEMP/SAL - Match the times from series2 PHYSICAL dates to this series of continuous mondays
    % correct series2 temp/sal dates and skip a year and change idx 650:652 hurricane irene, Aug 2011 - Jan 2013
            series2tempSal.Date(1:105)=series2tempSal.Date(1:105) + years(1900);
            series2tempSal.Date(106:end)=series2tempSal.Date(106:end) + years(2000);
            % duplicate values 790:794
            series2tempSal(790:794,:)=[];
            
    % match mondays for series2 temp/salinity data
            for ii = 1:length(series3mondays)
                workingDate = series3mondays(ii);
                TFbet = isbetween(series2tempSal.Date,workingDate-LOWER,workingDate+UPPER);
                    if sum(TFbet)>=1
                        findTbet = find(TFbet==1);
                         matchMondaysTempSal(ii,:) = findTbet(1);
                    else
                         matchMondaysTempSal(ii,:) = NaN;
                    end
            end
            
    % copy the rows of data to a new table
        series2physical = table;
        series2tempSal.Date = [];
        series2tempSal.Time = [];
        nanRow=table;
%         nanRow = table(fieldnames(series2tempSal)');
        for i = 1:length(fieldnames(series2tempSal))-1
            nanRow{1,i}=NaN;
        end
        namesF = fieldnames(series2tempSal);
        namesF(end)=[];
        nanRow.Properties.VariableNames = namesF;
        
        for ii = 1:length(matchMondaysTempSal)
            if ~isnan(matchMondaysTempSal(ii))
                series2physical(ii,:) = series2tempSal(matchMondaysTempSal(ii),:);
            else
                series2physical(ii,1:end) = nanRow(1,1:end);
            end
        end
        series2physical.DATE = series3mondays';

%% SERIES2 PHYTO - Match the times from series2 PHYTO dates to this series of mondays

    % match mondays for series2 phytoplankton data
            for ii = 1:length(series3mondays)
                workingDate = series3mondays(ii);
                TFbet = isbetween(series2phytoAvgDel.DATE,workingDate-LOWER,workingDate+UPPER);
                    if sum(TFbet)>=1
                        findTbet = find(TFbet==1);
                         matchMondaysPhyto(ii,:) = findTbet(1);
                    else
                         matchMondaysPhyto(ii,:) = NaN;
                    end
            end
            
    % copy the rows of data to a new table
        series2phytoAvgDelMondays = table;
        series2phytoAvgDel.DATE = [];
        nanRow=table;
        for i = 1:length(fieldnames(series2phytoAvgDel))-1
            nanRow{1,i}=NaN;
        end
        namesF = fieldnames(series2phytoAvgDel);
        namesF(end)=[];
        nanRow.Properties.VariableNames = namesF;
        
    % create a new table mapped to the continuous series 
        for ii = 1:length(matchMondaysTempSal)
            if ~isnan(matchMondaysTempSal(ii))
                series2phytoAvgDelMondays(ii,:) = series2phytoAvgDel(matchMondaysTempSal(ii),:);
            else
                series2phytoAvgDelMondays(ii,1:end) = nanRow(1,1:end);
            end
        end
        series2phytoAvgDelMondays.DATE = series3mondays';

%% SERIES2 CHL - Match the times from series2 CHL dates to this series of mondays
    % correct series2 temp/sal dates and skip a year and change idx 650:652 hurricane irene, Aug 2011 - Jan 2013
            series2chl.SampleDate1(1:50)=series2chl.SampleDate1(1:50) + years(1900);
            series2chl.SampleDate1(51:end)=series2chl.SampleDate1(51:end) + years(2000);
            
    % match mondays for series2 chl data
            for ii = 1:length(series3mondays)
                workingDate = series3mondays(ii);
                TFbet = isbetween(series2chl.SampleDate1,workingDate-LOWER,workingDate+UPPER);
                    if sum(TFbet)>=1
                        findTbet = find(TFbet==1);
                         matchMondaysChl(ii,:) = findTbet(1);
                    else
                         matchMondaysChl(ii,:) = NaN;
                    end
            end
            
    % copy the rows of data to a new table
        series2chlNew = table;
        series2chl.SampleDate = [];
        series2chl.SampleDate1 = [];
        nanRow=table;
        for i = 1:length(fieldnames(series2chl))-1
            nanRow{1,i}=NaN;
        end
        namesF = fieldnames(series2chl);
        namesF(end)=[];
        nanRow.Properties.VariableNames = namesF;
        
    % create a new table mapped to the continuous series 
        for ii = 1:length(matchMondaysChl)
            if ~isnan(matchMondaysChl(ii))
                series2chlNew(ii,:) = series2chl(matchMondaysChl(ii),:);
            else
                series2chlNew(ii,1:end) = nanRow(1,1:end);
            end
        end
%         series2chlNew.DATEc = series3mondays';

%% SERIES2 N/P - Match the times from series2 NP dates to this series of continuous mondays
    % correct series2 temp/sal dates and skip a year and change idx 650:652 hurricane irene, Aug 2011 - Jan 2013
%             series2NitrogenPhosphate.DATE(1:50)=series2NitrogenPhosphate.DATE(1:50) + years(1900);
            series2NitrogenPhosphate.DATE=series2NitrogenPhosphate.DATE + years(2000);
            series2NitrogenPhosphate.DATE(475) = series2NitrogenPhosphate.DATE(475) - years(14);
            
    % match mondays for series2 chl data
            for ii = 1:length(series3mondays)
                workingDate = series3mondays(ii);
                TFbet = isbetween(series2NitrogenPhosphate.DATE,workingDate-LOWER,workingDate+UPPER);
                    if sum(TFbet)>=1
                        findTbet = find(TFbet==1);
                         matchMondaysNP(ii,:) = findTbet(1);
                    else
                         matchMondaysNP(ii,:) = NaN;
                    end
            end
            
    % copy the rows of data to a new table
        series2NP = table;
        series2NitrogenPhosphate.DATE = [];
        
    % create a placehold row for days not sampled
        nanRow=table;
            for i = 1:length(fieldnames(series2NitrogenPhosphate))-1
                nanRow{1,i}=NaN;
            end
            namesF = fieldnames(series2NitrogenPhosphate);
            namesF(end)=[];
            nanRow.Properties.VariableNames = namesF;
        
            series2NP(1,:)= nanRow(1,:);
    % create a new table mapped to the continuous series 
        for ii = 1:length(matchMondaysNP)
            if ~isnan(matchMondaysNP(ii))
                series2NP(ii,:) = series2NitrogenPhosphate(matchMondaysNP(ii),:);
            else
                series2NP(ii,1:end) = nanRow(1,:);
            end
        end
%         series2chlNew.DATEc = series3mondays';

%% SERIES2 Silica - Match the times from series2 SI dates to this series of continuous mondays
            series2Silica.DATE=series2Silica.DATE + years(2000);
            
    % match mondays for series2 SI data
            for ii = 1:length(series3mondays)
                workingDate = series3mondays(ii);
                TFbet = isbetween(series2Silica.DATE,workingDate-LOWER,workingDate+UPPER);
                    if sum(TFbet)>=1
                        findTbet = find(TFbet==1);
                         matchMondaysSI(ii,:) = findTbet(1);
                    else
                         matchMondaysSI(ii,:) = NaN;
                    end
            end
            
    % copy the rows of data to a new table
        series2SI = table;
        series2Silica.DATE = [];
        series2Silica.DATE1 = [];
        
    % create a placeholder row for days not sampled
        nanRow=table;
            for i = 1:length(fieldnames(series2Silica))-1
                nanRow{1,i}=NaN;
            end
            namesF = fieldnames(series2Silica);
            namesF(end)=[];
            nanRow.Properties.VariableNames = namesF;
        
            series2SI(1,:)= series2Silica(1,:);
    % create a new table mapped to the continuous series 
        for ii = 1:length(matchMondaysSI)
            if ~isnan(matchMondaysSI(ii))
                series2SI(ii,:) = series2Silica(matchMondaysSI(ii),:);
            else
                series2SI(ii,1:end) = nanRow(1,:);
            end
        end
%         series2chlNew.DATEc = series3mondays';

%% combine the series 2 temp/sal with the series2 chl and NP and SI. 
    series2physical = [series2physical, series2chlNew, series2NP, series2SI];

%% average the series2physical data for combination with series 1. Convert units to match
    % combine the surface and deep chla/SInutrient/SI with All corrected values by averaging, create a
        % single variable and convert to series1 units
        series2physical.AveragedChla = nanmean([series2physical.surfacechlaall, series2physical.BottomChlaall1],2) .* 10; % micrograms per liter (ug/L)
        series2physical.AveragedNH4 = nanmean([series2physical.NH4, series2physical.NH4deep],2) .*10 ; % micromol
        series2physical.AveragedSi = nanmean([series2physical.Si, series2physical.Sideep],2) .*10; % micromol
        series2physical.AveragedDIP = nanmean([series2physical.DIP, series2physical.DIPdeep],2) .*10; % micromol
        series2physical.AveragedNO3 = nanmean([series2physical.NO3, series2physical.NO3deep],2) .*10; % micromol
        series2physical.AveragedNO3plus2 = nanmean([series2physical.NO3plus2, series2physical.NO3plus2deep],2); % micromol
        series2physical.AveragedNO2 = nanmean([series2physical.NO2, series2physical.NO2deep],2); % micromol
        series2physical.AveragedNO2 = nanmean([series2physical.NO2, series2physical.NO2deep],2); % micromol
        series2physical.AveragedDIN = nanmean([series2physical.DIN, series2physical.DINdeep],2); % micromol
        
        namesSeries2physical = fieldnames(series2physical);
        namesSeries2physical(end)=[];

    % series 1 chla is given as miligrams per m2 over 9 meters or
        % mg/9m3. Series 2 is micrograms per liter (ug/L) Convert the
        % series1 data here:
        
    % Series1 Methods Nutrient Smayda: During 1959 to 1963 nitrate/si/po4 was determined manually
        % During 1972 to 1997 nitrate was determined via  manual colormetric methods
        % (Strickland and Parsons, 1965) or automated colormetric methods using 
        % an autoanalyzer following the methodologies of Furnas (1982; J. Plankt. Res. 5, 637-655) 
        % and Furnas (1983, J. Plankt. Res. 5, 637-655 ).  Concentration per m2 calculated 
        % from surface, mid and bottom measurements integrated over 9 m deep water column.
    
    % Series1 Methods Chl Smayda: Chlorophyll determined using the fluorometric method of Yentsch and Menzel (1963) 
        % as described in Li and Smayda (1998; ICES J. Mar Sci. 55: 661-667).  Concentration per m2 
        % calculated from surface, mid and bottom measurements integrated over 9 m deep water column.
    
%% rename the series1 phyto data to series2 names, Combine Series1 phyto and series2 phyto
    series3phyto = table;
    for i = 1:length(namesNew)
        try
            series3phyto.(namesNew{i})= [series1phyto.(namesOld{i}); series2phytoAvgDelMondays.(namesNew{i})];
        catch
        end
    end        

%% match names: the series1 and series2 physical data
load namesRemovePhysical
        namesOldPhysical = fieldnames(series1physical);
        namesNewPhysical = namesRemovePhysical(:,2);

        findEmptyNamesPhysical = find(cellfun(@isempty,namesRemovePhysical(:,2)));
        namesOldRemovePhysical = namesOldPhysical(findEmptyNamesPhysical);
        namesOldPhysical(findEmptyNamesPhysical) = [];
        namesOldPhysical(end)=[];
        namesNewPhysical(findEmptyNamesPhysical) = [];

% Remove nutrient integration and chl integration for now
%         namesOldPhysical(3:6)=[];
%         namesOldPhysical(end)=[];
%         namesNewPhysical(3:6)=[];

%% Remove the empty physical fields from series 1, merge with series 2
    series3physical = table;
    for i = 1:length(namesOldPhysical)
        series3physical.(namesOldPhysical{i}) = [series1physical.(namesOldPhysical{i}); series2physical.(namesNewPhysical{i})];
    end

%% Merge the series3 Physical and series3 Phyto data Tables
    series3 = [series3phyto,series3physical];

%% QA the results
    fn=fieldnames(series3);
    for i =104:width(series3)
        figure(1)
        plot([series3.DATE],series3.(fn{i}))
        title([fn{i}])
        pause
    end

%% Export series3 to a csv file!
    fid = ['mergedNABATSv',num2str(mergeVersion)];
    writetable(series3,fid);
    