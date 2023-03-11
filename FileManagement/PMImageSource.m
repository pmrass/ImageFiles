classdef PMImageSource
    %PMIMAGESOURCE for reading image data from file
    %  Uses "Settings" and "ImageMapList" to know where to read;
    
    properties (Access = private)
        ImageMapPerFile
        Settings
        Navigation % used to get max channel and max frame of image-sequence;
        
    end
    
    properties (Constant)
         TimeColumn =                                    10;
    end
    
    methods
        
        function obj = PMImageSource(varargin)
            %PMIMAGESOURCE Construct an instance of this class
            %   takes 2 or 3 argument:
            % 1: ImageMap per file: can be created with PMImageFiles object;
            % 2: PMNavigationSeries object: can be created with PMImageFiles object;
            % 3: Settings
            NumberOfArguments= length(varargin);
            switch NumberOfArguments
                case 2
                    obj.ImageMapPerFile = varargin{1};
                    obj.Navigation =      varargin{2};
                    
                case 3
                    obj.ImageMapPerFile = varargin{1};
                    obj.Navigation =      varargin{2};
                    obj.Settings =        varargin{3}; 
                    
                otherwise
                    error('Wrong number of arguments.')
            end
            
            
        end
        
    
        
             
    end
    
    methods % GETTERS
        
        function ImageVolume =      getImageVolume(obj)
        % GETIMAGEVOLUME getImageVolume
        % returns 5-dimensional uint8 numerical matrix:
        % dimension 1: rows
        % dimension 2: columns
        % dimension 3: planes
        % dimension 4: time-frames
        % dimension 5: channels:


            FinalizedImageMap =          obj.getFinalizedImageMap;
            ImageVolume =               obj.getInitializedImageVolume(FinalizedImageMap);
            for Index = 1 : size(FinalizedImageMap,1)
                currentDirectory =      PMImageDirectory(FinalizedImageMap(Index,:));
                ImageVolume =           currentDirectory.drawOnImageVolume(ImageVolume);
            end

        end

        function MergedImageMap =   getImageMap(obj)
          % GETIMAGEMAP get merged image map (all individual image-maps will be merged);
          % returns complete image map with complete information of image source;
          % image maps from different movie files are pooled and time-frames are adjusted;
          % frame numbers in image map are adjusted if necessary;

            switch obj.getImageOrderType

                case 'OneImageForEachFrame'
                    FramesPerMap =           cellfun(@(x) max(cell2mat(x(2:end, obj.TimeColumn))), obj.ImageMapPerFile);
                    CumulativeTemp =         cumsum(FramesPerMap);
                    adjustingTimeFrames =    [0; CumulativeTemp(1:end-1)];

                case 'OneImageForEachChannelPerFrame'
                    adjustingTimeFrames =    linspace(0,obj.Navigation.getMaxFrame-1,obj.Navigation.getMaxFrame);
                    adjustingTimeFrames =    repmat(adjustingTimeFrames, obj.Navigation.getMaxChannel,1);
                    adjustingTimeFrames =    adjustingTimeFrames(:);

                case 'NavigationAndImageMaxFrameMatch'
                    adjustingTimeFrames =   '';

                otherwise
                    error('Unknown pattern.')
            end

            ImageMap =                  obj.adjustFramesOfImageMap(adjustingTimeFrames);
            ImageMapsWithoutTitles =    cellfun(@(x) x(2:end,:), ImageMap, 'UniformOutput', false);
            MergedImageMap =            [obj.ImageMapPerFile{1,1}(1,:); vertcat(ImageMapsWithoutTitles{:})];
        end

        function Sequences =        getBitSequencesForStripIndex(obj, Index)
            Sequences = arrayfun(@(x) x.getBitSequenceForStripIndex(Index), obj.getImageMapArray, 'UniformOutput', false);

         end
          
    end
    

    methods (Access = private) % GETTERS IMAGE MAP
        
        function FilteredImageMap =     getFinalizedImageMap(obj)
            % GETFINALIZEDIMAGEMAP
            % returns merged image map without title; 
            % Settings also filters out unwanted rows (with wrong frame, plane or channels;
            % Settings will "reposition" image map in space and time: for example a single time frame "19" can be set to "1";
             FilteredImageMap =              obj.getImageMap;   
            
             FilteredImageMap =              obj.removeUnwantedEntriesFromImageMap(FilteredImageMap);   
             FilteredImageMap =              obj.resetPositionsOfImageMap(FilteredImageMap);   
             FilteredImageMap(1,:) =         []; % delete title;
            
        end
        
        function ImageMapList =         getImageMapArray(obj)
                FinalizedImageMap =          obj.getFinalizedImageMap;
                
                for Index = 1 : size(FinalizedImageMap,1)
                    ImageMapList(Index, 1) =      PMImageDirectory(FinalizedImageMap(Index,:));
                   
                end
            
        end
         
    end
    
    
    
    methods (Access = private) % GETTERS: RELEVANT IMAGE MAP AFTER FILTERING OUT IRRELEVANT ROWS;
        
        function ImageMap =             removeUnwantedEntriesFromImageMap(obj, ImageMap)
            if ~isempty(obj.Settings)
                [ImageMap] =                        obj.removeUnwantedImageMapRows(ImageMap, obj.Settings,'TargetFrameNumber'); % filter for frames
                [ImageMap] =                        obj.removeUnwantedImageMapRows(ImageMap, obj.Settings,'TargetPlaneNumber'); % filter for planes
                [ImageMap] =                        obj.removeUnwantedImageMapRows(ImageMap, obj.Settings,'TargetChannelIndex'); % filter for channels
            end 
        end

        function NewImageMap =          removeUnwantedImageMapRows(obj, ImageMap, Settings, FilterCode)

              switch FilterCode
                    case 'TargetFrameNumber'
                        ListWithWantedNumbers =         Settings.SourceFrames;
                    case 'TargetPlaneNumber'
                        ListWithWantedNumbers =         Settings.SourcePlanes;
                    case 'TargetChannelIndex'
                         ListWithWantedNumbers =         Settings.SourceChannels;   
                end

                FilteredImageMap =          ImageMap(2:end,:);
                if ~isempty(ListWithWantedNumbers)

                    ColumnWithWantedParameter =                                 strcmp(FilterCode, obj.getColumnTitles);
                    assert(sum(ColumnWithWantedParameter) == 1, 'Chosen column is not unique.')

                    RowsThatShouldBeKept =                                      false(size(FilteredImageMap,1), length(ListWithWantedNumbers));
                    for CurrentIndex = 1 : length(ListWithWantedNumbers)
                        RowsThatShouldBeKept(:, CurrentIndex) =                  cell2mat(FilteredImageMap(:,ColumnWithWantedParameter)) == ListWithWantedNumbers(CurrentIndex);
                    end
                    RowsThatShouldBeKept =                                      max(RowsThatShouldBeKept, [], 2);
                    FilteredImageMap=                                       FilteredImageMap(RowsThatShouldBeKept,:);
                end
                NewImageMap = [obj.getColumnTitles; FilteredImageMap];
        end

        function ColumnTitles =         getColumnTitles(obj)
            ColumnTitles =                           obj.ImageMapPerFile{1}(1,:);
        end

        
    end
    
    methods (Access = private) % GETTERS: RESET FRAMES, PLANES, AND CHANNELS OF IMAGE MAP;
        
        function ImageMap =         resetPositionsOfImageMap(obj, ImageMap)
         if ~isempty(obj.Settings)
             %% then reset the numbers of the images in the file to rearrange if needed;
             % for example, you may want to change time frame from 10 to 1 if you want just a single image volume rather than a time-series;
            [ImageMap] =                        obj.resetImageMap(ImageMap, obj.Settings,'TargetFrameNumber'); % replace source frame numbers wiht target frame numbers
            [ImageMap] =                        obj.resetImageMap(ImageMap, obj.Settings,'TargetPlaneNumber'); 
            [ImageMap] =                        obj.resetImageMap(ImageMap, obj.Settings,'TargetChannelIndex');
         end   

      end
          
        function ImageMap =         resetImageMap(obj, ImageMap, Settings, FilterCode)
            switch FilterCode
                case 'TargetFrameNumber'
                    SourceNumbers =                 Settings.SourceFrames;
                    TargetNumbers =                 Settings.TargetFrames;

                case 'TargetPlaneNumber'
                    SourceNumbers =                 Settings.SourcePlanes;
                    TargetNumbers =                 Settings.TargetPlanes;

                case 'TargetChannelIndex'
                    SourceNumbers =                 Settings.SourceChannels;
                    TargetNumbers =                 Settings.TargetChannels;
            end

            WantedColumn =                      strcmp(FilterCode, obj.getColumnTitles);
            ImageMapForFiltering =              ImageMap(2:end,:);
            for ChangeIndex = 1 :  length(SourceNumbers)
                oldValue =                      SourceNumbers(ChangeIndex);
                newValue =                      TargetNumbers(ChangeIndex);
                RowsThatNeedChange =                                        cell2mat(ImageMapForFiltering(:,WantedColumn)) == oldValue;
                ImageMapForFiltering(RowsThatNeedChange,WantedColumn) =        {newValue};

            end
            ImageMap = [obj.getColumnTitles; ImageMapForFiltering];
        end

    end
    
    methods (Access = private) % GETTERS: ADJUST FRAMES FOR POOLING IMAGE MAPS;
       
        function ImageMap =     adjustFramesOfImageMap(obj, adjustingTimeFrames)
              % ADJUSTFRAMESOFIMAGEMAP shifts the frames in consecutive movie-sequences;
              % input vector with "frame-shift" for each movie; 
              % will be used to set frame numbers of image map;
             
                 if isempty(adjustingTimeFrames)
                     
                 else
                     
                    assert(isvector(adjustingTimeFrames) && isnumeric(adjustingTimeFrames) && length(adjustingTimeFrames) == obj.getNumberOfImageMaps , 'Wrong input.')
                      
                    ImageMap = obj.ImageMapPerFile;
                    for CurrentMapIndex = 1: obj.getNumberOfImageMaps 
                        OldMapNumbers =                   cell2mat(obj.ImageMapPerFile{CurrentMapIndex,1}(2:end, obj.TimeColumn));
                        ImageMap{CurrentMapIndex,1}(2:end, obj.TimeColumn) =         num2cell(OldMapNumbers + adjustingTimeFrames(CurrentMapIndex));
                    end
                end
          end
            
        function number =       getNumberOfImageMaps(obj)
                 number =     size(obj.ImageMapPerFile,1);
          end
        
        
    end
    
    methods(Access = private) % GETTERS: getImageOrderType;
      
        function type =             getImageOrderType(obj) 

            if obj.Navigation.getMaxFrame ==  obj.getNumberOfFramesInImageMap
                type = 'OneImageForEachFrame';

            elseif obj.Navigation.getMaxFrame == obj.getNumberOfEntriesInImageMap / obj.Navigation.getMaxChannel
                type = 'OneImageForEachChannelPerFrame';

            elseif obj.Navigation.getMaxFrame == obj.getMaximumFrameOfImageMap
                type = 'NavigationAndImageMaxFrameMatch';

            else
                error('Cannot interpret time-series')

            end
        end

        function frameNumber =      getNumberOfFramesInImageMap(obj)
            frameNumber =     sum(obj.getMaximumFramesPerImageMap);
        end

        function maximumFrames =    getMaximumFramesPerImageMap(obj)
             maximumFrames =           cellfun(@(x) max(cell2mat(x(2:end, obj.TimeColumn))), obj.ImageMapPerFile);
        end

        function value =            getNumberOfEntriesInImageMap(obj)
            value = size( obj.getPooledImageMapWithoutTitle,1);
        end

        function pooledImageMap =   getPooledImageMapWithoutTitle(obj)
            pooledImageMap =        cellfun(@(x) x(2:end,:), obj.ImageMapPerFile, 'UniformOutput', false);
            pooledImageMap =        vertcat(pooledImageMap{:});
        end

        function maximumFrame =     getMaximumFrameOfImageMap(obj)
           maximumFrame =  max(obj.getFramesFromImageMap);
        end

        function frames =           getFramesFromImageMap(obj)
            pooledImageMap =        obj.getPooledImageMapWithoutTitle;
            frames =                cell2mat(pooledImageMap(:, obj.TimeColumn));
        end

    end
    
    methods (Access = private) % GETTER INITIALIZED IMAGE MAP
        
        function image =                getInitializedImageVolume(obj, ImageMap)

            image=                         cast(uint8(0), obj.getPrecisionFromImageMap(ImageMap));

            image(                  obj.getNumberOfRowsFromImageMap(ImageMap), ...
                                    obj.getNumberOfColumnsFromImageMap(ImageMap), ...
                                    obj.getNumberOfPlanesFromImageMap(ImageMap), ...
                                    obj.getNumberOfFramesFromImageMap(ImageMap), ...
                                    obj.getNumberOfChannelsFromImageMap(ImageMap))=                          0;


        end

        function Precision =            getPrecisionFromImageMap(obj, FilteredImageMap)
            if isempty(FilteredImageMap)
                Precision =                   'uint8';
            else
                PrecisionList =                     unique(FilteredImageMap(:,6));
                assert(length(PrecisionList)==1, 'Cannot read file. Reason: precision of different image elements is not identical')
                Precision =                         PrecisionList{1,1};
            end
        end

        function numberOfRows =         getNumberOfRowsFromImageMap(obj, FilteredImageMap)
        if isempty(FilteredImageMap)
            numberOfRows = 1;
        else
            TotalRowsOfImageList =              unique(cell2mat(FilteredImageMap(:,9)));
            assert(length(TotalRowsOfImageList)==1, 'Cannot read file. Reason: precision of different image elements is not identical')
            numberOfRows =                  TotalRowsOfImageList(1,1);
        end 
        end

        function numberOfColumns =      getNumberOfColumnsFromImageMap(obj, FilteredImageMap)
        if isempty(FilteredImageMap)
            numberOfColumns = 1;
        else
             TotcalColumnsOfImageList =         unique(cell2mat(FilteredImageMap(:,8)));
            assert(length(TotcalColumnsOfImageList)==1, 'Cannot read file. Reason: precision of different image elements is not identical')
            numberOfColumns =             TotcalColumnsOfImageList(1,1);
        end
        end

        function numberOfPlanes =       getNumberOfPlanesFromImageMap(obj, FilteredImageMap)
             if isempty(FilteredImageMap)
                 numberOfPlanes = 1;
             else
                 ColumnForPlanes =                           strcmp(getColumnTitles(obj), 'TargetPlaneNumber');
                numberOfPlanes =                               max(cell2mat(FilteredImageMap(:,ColumnForPlanes)));
             end

        end

        function numberOfChannels =     getNumberOfChannelsFromImageMap(obj, FilteredImageMap)
         if isempty(FilteredImageMap)
             numberOfChannels = 1;
         else
             numberOfChannels =                     max(cell2mat(FilteredImageMap(:,15)));

         end

        end

        function numberOfFrames =       getNumberOfFramesFromImageMap(obj, FilteredImageMap)
             if isempty(FilteredImageMap)
                 numberOfFrames = 1;
             else
                 ColumnForFrames =                           strcmp(getColumnTitles(obj), 'TargetFrameNumber');
                numberOfFrames =                               max(cell2mat(FilteredImageMap(:,ColumnForFrames)));

             end

        end

    end
    
    methods (Access = private) % CURRENTLY NOT USED:
       
         
        function [NonObjectImageMap] =                       ResetChannelsInImageMap(obj, NonObjectImageMap, oldValue, newValue)
            myImageMap =                                                obj.getImageMap; 
            WantedColumn =                                              strcmp('TargetChannelIndex', myImageMap(1,:));
            RowsThatNeedChange =                                        cell2mat(NonObjectImageMap(:,WantedColumn)) == oldValue;
            NonObjectImageMap(RowsThatNeedChange,WantedColumn) =        {newValue};
            
        end
        
        function [NonObjectImageMap] =                       ResetFramesInImageMap(obj, NonObjectImageMap, oldValue, newValue)
            myImageMap =                                                obj.getImageMap; 
            WantedColumn =                                              strcmp('TargetFrameNumber', myImageMap(1,:));
            RowsThatNeedChange =                                        cell2mat(NonObjectImageMap(:,WantedColumn)) == oldValue;
            NonObjectImageMap(RowsThatNeedChange,WantedColumn) =        {newValue};
        end
        
        function [NonObjectImageMap] =                       ResetPlanesInImageMap(obj, NonObjectImageMap, oldValue, newValue)
            myImageMap =                                                obj.getImageMap; 
            WantedColumn =                                              strcmp('TargetPlaneNumber', myImageMap(1,:));
            RowsThatNeedChange =                                        cell2mat(NonObjectImageMap(:,WantedColumn)) == oldValue;
            NonObjectImageMap(RowsThatNeedChange,WantedColumn) =        {newValue};
        end
        
    end
end

