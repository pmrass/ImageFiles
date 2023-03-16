classdef PMCZIMetaData
    %PMCZIDOCUMENT read meta-data from CZI files
    %   provides methods that allow retrieval of metadata;
    %   for example: getImageMap provides information to read individual images contained within czi file;
    
    properties (Access = private)
        FileName
        
        SegmentList %
        % SegmentListColumns = {'ID';'OffsetHeader';'OffsetData';'AllocatedSize';'UsedSize'; structure with actual content};
        FilePointer
        
        MetaData
        ImageMap
        WantedPosition
        RequiredDimensions =                    {'X', 'Y', 'Z', 'C', 'T', 'S', 'H', 'M'};

    end

    properties (Access = private) % derivative data:
        AllDimensionKeys
        DimensionSummary

    end
    
    methods % INITIALIZE
        
        function obj =          PMCZIMetaData(varargin)
            %PMCZIDOCUMENT Construct an instance of this class
            %   takes 1 or 2 arguments:
            % 1: filename
            % 2: index of wanted scene (numerics scalar or empty);
            switch length(varargin)
               
                case 1
                    obj.FileName =          varargin{1};
                    
                case 2
                    obj.FileName =          varargin{1};
                    obj.WantedPosition =    varargin{2};
                
            end
            
            obj.SegmentList =       obj.getSegments;
            obj.ImageMap =          obj.getImageMapInternal;
            obj.MetaData =          obj.getMetaDataInternal;
            obj =                   obj.AdjustMetaDataByImageMap;

            obj =                   obj.setDimensionSummary;
            
        end
        
        function obj = set.WantedPosition(obj, Value)
            assert(isempty(Value) || (isscalar(Value) && isnumeric(Value) && Value > 0 && mod(Value, 1) == 0), 'Wrong input.')
           obj.WantedPosition = Value; 
        end
            
    end

      methods % GETTERS: STITCHING

        function  [Stitching ] =        getStitchingStructureForChannelIndex(obj, ChannelIndex)
            MyDimensionSummary =           obj.getDimensionSummaryForIndex( ChannelIndex);
            Stitching.X =                  obj.getStitchingStructureForInput(MyDimensionSummary, 'X');
            Stitching.Y =                  obj.getStitchingStructureForInput(MyDimensionSummary, 'Y');
        end

        function [Stitching ] =         getStitchingStructure(obj)
             [Stitching ] =        obj.getStitchingStructureForChannelIndex(1);
         end

    end

    methods % GETTERS IMAGE-MAP
        
          function imageMap =           getImageMap(obj, varargin)
                imageMap = obj.ImageMap;
          end
           
    end
    
    methods % GETTERS DIMENSIONS
        
        function number =               getNumberOfScences(obj)
            % GETNUMBEROFSCENCES returns number of scenes (1 is default);
            DimensionEntries =      obj.getDimensionInfoFor(obj.getAllImageSegments, 'S');
            if isempty(DimensionEntries)
                number = 1;
            else
                number =                max(cellfun(@(x) x.Start, DimensionEntries))  + 1;
            end

        end

    end


    
    methods % GETTERS
        
        function ImageSegments =        getAllImageSegments(obj)
            ImageSegments =         obj.SegmentList(cellfun(@(x) contains(x, 'ZISRAWSUBBLOCK'), obj.SegmentList(:,1)),:);
        end

        function list =                 getSegmentList(obj)
            list = obj.SegmentList;
        end

        function metaData =             getMetaData(obj)
            % GETMETADATA returns meta-data structure;
            metaData = obj.MetaData;
        end
        
        function string =               getMetaDataString(obj)
            % GETMETADATASTRING returns entire meta-data string of the file;
                string =                    obj.SegmentList{cellfun(@(x) contains(x, 'ZISRAWMETADATA'), obj.SegmentList(:,1)),6};
        end
        
        function Summary =              getObjectiveSummary(obj)
            % GETOBJECTIVESUMMARY returns summary text describing objective;
            ObjectiveStructure =                obj.getObjectiveStructure;
            ObjectiveStructure.Name =           obj.getObjectiveName;
            ObjectiveStructure.Identifier =     obj.getIdentifierForObjectiveName(ObjectiveStructure.Name);
            myObjective =                       PMObjective(ObjectiveStructure);
            Summary =                           myObjective.getSummary;
        end
        
        function string =               getImageCaptureSummary(obj)
            % GETIMAGECAPTURESUMMARY returns relevant XML text about image-capture;
            myString =                  obj.getMetaDataString;
            xmlParser =                 PMXML(myString);
            ImageData =                 xmlParser.getElementContentsWithTitle('Image');
             
            assert(length(ImageData) == 1, 'Cannot process multiple Image fields.')
            ChannelData =               PMXML(ImageData{1}).getElementContentsWithTitle('Channels');
            string =                    splitlines(ChannelData);  
        end
        
        function value =                getFileCouldBeAccessed(obj)
            value =         obj.getPointer ~= -1;
        end

    end

    methods (Access = private)  % FILE-MANAGEMENT
    
        function pointer =              getPointer(obj)
            pointer = fopen(obj.FileName,'r','l');
            
        end
        
    end

    methods (Access = private) % GETTERS: STITCHING

         function obj = setDimensionSummary(obj)
            obj =               obj.setDimensionSummaryFor('Start');
            obj =               obj.setDimensionSummaryFor('Size');
            obj =               obj.setDimensionSummaryFor('StartCoordinate');
            obj =               obj.finalizeDimensionSummary;
         end

         function obj = setDimensionSummaryFor(obj, Parameter)
            ImageSegments =                         obj.getAllImageSegments;
            Starts =                                cellfun(@(x)  ...
                                                        obj.getDimensionValues(x.Directory.DimensionEntries, obj.RequiredDimensions, Parameter), ...
                                                        ImageSegments(:, 6), ...
                                                        'UniformOutput',false);
            FieldName =                             ['Summary', Parameter];
            obj.DimensionSummary.(FieldName) =      obj.processMatrix(Starts);

         end

        function [SummaryStart] = processMatrix(obj, Starts)
        
            SummaryStart =                          vertcat(Starts{:});
            Empty =                                 cellfun(@(x) isempty(x), SummaryStart);
            MyType =                                class(SummaryStart{1});
            SummaryStart(Empty) =                   {cast(0, MyType)};
            SummaryStart =                          cell2mat(SummaryStart);
            
        
        end


         function obj = finalizeDimensionSummary(obj)

             ImageSegments =                                     obj.getAllImageSegments;
             obj.AllDimensionKeys =                              obj.getAllDimensionKeysForEntries(ImageSegments{1, 6}.Directory.DimensionEntries);
              for index = 1 : length(obj.RequiredDimensions)
                 CurrentDimension =                     obj.RequiredDimensions{index};
                 if max(strcmp(CurrentDimension, obj.AllDimensionKeys)) == 0
                    obj.DimensionSummary.SummaryStart(:, index) =            0;
                    obj.DimensionSummary.SummarySize(:, index) =             1;
                    obj.DimensionSummary.SummaryStartCoordinate(:, index) =  0;

                 end
             end

            obj.DimensionSummary.SummaryStart(:, 3 : end) =      obj.DimensionSummary.SummaryStart(:, 3 : end) + 1;

         end

    

         
             

         function [SummaryStart ] = getDimensionValues(obj, MyDimensionEntries, TargetColumnNames, Parameter)


             for index = 1 : length(MyDimensionEntries)

                 CurrentDimensionEntry =                    MyDimensionEntries{index};
                 DimensionName =                            CurrentDimensionEntry.Dimension(1);
                 TargetColumn =                             find(strcmp(DimensionName, TargetColumnNames));
                 assert(length(TargetColumn) == 1, 'Column designation mismatch.')

                 SummaryStart{1, TargetColumn} =            CurrentDimensionEntry.(Parameter);
              
             end


         end

        function [DimensionSummary] = getDimensionSummaryForIndex(obj, ChannelIndex)

            DimensionSummary.SummaryStart =                                 obj.DimensionSummary.SummaryStart;
            DimensionSummary.SummarySize =                                  obj.DimensionSummary.SummarySize;
            DimensionSummary.SummaryStartCoordinate =                           obj.DimensionSummary.SummaryStartCoordinate;

            FirstChannelRows =                                                  DimensionSummary.SummaryStart(:, 4) == ChannelIndex;
          
            DimensionSummary.SummaryStart(~FirstChannelRows, :) =               [];
            DimensionSummary.SummarySize(~FirstChannelRows, :) =                [];
            DimensionSummary.SummaryStartCoordinate(~FirstChannelRows, :) =     [];


        end
 
        function [StitchingStructure ] = getStitchingStructureForInput(obj, MyStructure, Dimension)

            switch Dimension

                case 'X'
                    Column = 1;

                case 'Y'
                    Column = 2;

            end

                Start =                         MyStructure.SummaryStart(:, Column);
                XShifts =                       Start - min(Start);

                SizeList =                      MyStructure.SummarySize(:, Column);
                XSize =                        unique(SizeList);
                assert(length(XSize) == 1, 'All sizes must be the same.')
              
                StartCoordinate =               MyStructure.SummaryStartCoordinate(:, Column);
                StartCoordinates =              unique(StartCoordinate);
                assert(length(StartCoordinates) == 1, 'All start-coordinates must be the same.')
                assert( StartCoordinates== 0, 'All start-coordinates must be zero.')
                
                 StitchingStructure.TotalSize =     max(XShifts) + XSize;
                 StitchingStructure.PanelSizes =     SizeList;
                 StitchingStructure.Shifts =        XShifts;

            end

           
            
            
            
         
            
            
             

               
                

         end
        
    methods (Access = private) % GETTERS: IMAGE-SEGMENTS;
    
        function ImageSegments =    getImageSegementsOfSelectedScenes(obj)

            ImageSegments =                                 obj.getAllImageSegments;

            if ~isempty(obj.WantedPosition)
                
                ImageSegments =                             obj.getAllImageSegments;
                SceneDimensionEntries =                     obj.getDimensionInfoFor(ImageSegments, 'S');
                SceneNumbers =                              cellfun(@(x) x.Start + 1, SceneDimensionEntries);
                MatchingIndices =                           SceneNumbers == obj.WantedPosition;
                ImageSegments(~MatchingIndices, :) =        [];

            end

        end

      

      

    end
    
    methods (Access = private) % GETTERS IMAGE MAP
        
          function WantedDimensionEntries =   getDimensionInfoFor(obj, ImageSegments, DimensionKey)
                AllDimensionEntries =                       cellfun(@(x) x.Directory.DimensionEntries, ImageSegments(:, 6), 'UniformOutput', false);
                WantedDimensionEntries =                    cellfun(@(x) obj.getDescriptionInDimensionEntriesForDimension(x, DimensionKey), AllDimensionEntries, 'UniformOutput', false);
                ToRemove =                                  cellfun(@(x) isempty(x), WantedDimensionEntries);
                WantedDimensionEntries(ToRemove) =          [];

        end
        
        function XDimensionData =           getDescriptionInDimensionEntriesForDimension(obj, DimensionEntries, WantedDimensionKey)
                
                AllDimensionKeys =      obj.getAllDimensionKeysForEntries(DimensionEntries);
                
                Index =                strcmp(AllDimensionKeys, WantedDimensionKey); 
                if max(Index) == 0
                    XDimensionData =        '';
                else
                    XDimensionData =       DimensionEntries{Index};
                end

        end

        function AllDimensionKeys = getAllDimensionKeysForEntries(obj, DimensionEntries)
             AllDimensionKeys =       cellfun(@(x) x.Dimension(1), DimensionEntries, 'UniformOutput', false);
               
        end


        function FinalImageMap =         getImageMapInternal(obj)
            % CREATEIMAGEMAP returns image map
            
      
               
                SelectedImageSegments =             obj.getImageSegementsOfSelectedScenes;
           
                MyImageMap =                        obj.getImageMapFileProperties(SelectedImageSegments);


                Structure =                         obj.getDimensionStructureFor(SelectedImageSegments);
                CompressionTypes =                  cellfun(@(x) obj.getComp(x), SelectedImageSegments(:, 6), 'UniformOutput',false);

                MyImageMap(:, 8) =                    num2cell(Structure.TotalColumnsOfImage);
                MyImageMap(:, 9) =                    num2cell(Structure.TotalRowsOfImage);
                MyImageMap(:, 10) =                   num2cell(Structure.TargetFrameNumber);
                MyImageMap(:, 11) =                   num2cell(Structure.TargetPlaneNumber);
                MyImageMap(:, 12) =                   num2cell(Structure.TotalRowsOfImage);
                MyImageMap(:, 14) =                   num2cell(Structure.TotalRowsOfImage);
                MyImageMap(:, 15) =                   num2cell(Structure.TargetChannelIndex);
                MyImageMap(:, 13) =                   {1};
                MyImageMap(:, 16) =                   {0};
                MyImageMap(:, 17)  =                  CompressionTypes;


                FinalImageMap =                     PMImageMap(MyImageMap).getImageMap;
 
        end

        function MyImageMap = getImageMapFileProperties(obj, SelectedImageSegments)

             ByteOrder =                         'ieee-le';
           

                Offsets =                           cellfun(@(x) x.OffsetForData, SelectedImageSegments(:, 6), 'UniformOutput',false);
                DataSizes =                         cellfun(@(x) x.DataSize, SelectedImageSegments(:, 6), 'UniformOutput',false);

                [BitsPerSample,Precision, SamplesPerPixel] = cellfun(@(x) obj.getPixelTypeProperties(x.Directory.PixelType), SelectedImageSegments(:, 6), 'UniformOutput',false);

                MyImageMap(:, 1)  =                   Offsets;
                MyImageMap(:, 2)  =                   DataSizes;

                MyImageMap(:, 4) =                    {ByteOrder};

                MyImageMap(:, 5)  =                   BitsPerSample;
                MyImageMap(:, 6)  =                   Precision;
                MyImageMap(:, 7)  =                   SamplesPerPixel;

        end

       
        function [BitsPerSample,Precision, SamplesPerPixel]  = getPixelTypeProperties(obj, PixelType)

              switch PixelType
                    case 'Gray8'
                        BitsPerSample =         8;
                        Precision =             'uint8';
                        SamplesPerPixel =       1;
                        
                    otherwise
                        error('Pixel type not supproted')
                end

        end
        

        function Structure = getDimensionStructureFor(obj, SelectedImageSegments)
            Structure.TotalColumnsOfImage =             cellfun(@(x) x.Size, obj.getDimensionInfoFor(SelectedImageSegments, 'X'));
            Structure.TotalRowsOfImage =                cellfun(@(x) x.Size, obj.getDimensionInfoFor(SelectedImageSegments, 'Y'));
            Structure.TargetPlaneNumber =               cellfun(@(x) x.Start, obj.getDimensionInfoFor(SelectedImageSegments, 'Z')) + 1;  
            Structure.TargetFrameNumber =               cellfun(@(x) x.Start, obj.getDimensionInfoFor(SelectedImageSegments, 'T')) + 1;
            Structure.TargetChannelIndex =              cellfun(@(x) x.Start, obj.getDimensionInfoFor(SelectedImageSegments, 'C')) + 1;

        end

        function Structure = getImapeMapStructure(obj)

                FieldsForImageReading.ListWithStripOffsets(:,1)=            MyImageFileDirectory.getStripOffsets;
                FieldsForImageReading.ListWithStripByteCounts(:,1)=         MyImageFileDirectory.getStripByteCounts;

                FieldsForImageReading.FilePointer =                         obj.FilePointer;
                FieldsForImageReading.ByteOrder =                           obj.Header.byteOrder;

                FieldsForImageReading.BitsPerSample=                        MyImageFileDirectory.getBitsPerSample;

                FieldsForImageReading.Precisision =                         MyImageFileDirectory.getPrecision;
                FieldsForImageReading.SamplesPerPixel =                     MyImageFileDirectory.getSamplesPerPixel;

                FieldsForImageReading.TotalColumnsOfImage=                  MyImageFileDirectory.getTotalColumns;
                FieldsForImageReading.TotalRowsOfImage=                     MyImageFileDirectory.getTotalRows;

                FieldsForImageReading.TargetFrameNumber =                   FrameNumber;
                FieldsForImageReading.TargetPlaneNumber =                   PlaneNumber;

                FieldsForImageReading.RowsPerStrip =                        MyImageFileDirectory.getRowsPerStrip; 
                
                FieldsForImageReading.TargetStartRows(:,1)=                 obj.getStripStartRows(MyImageFileDirectory.getRowsPerStrip, MyImageFileDirectory.getTotalRows);          
                FieldsForImageReading.TargetEndRows(:,1)=                   obj.getStripEndRows(MyImageFileDirectory.getRowsPerStrip, MyImageFileDirectory.getTotalRows);
                FieldsForImageReading.TargetChannelIndex=                   MyTargetChannelIndex;

                FieldsForImageReading.PlanarConfiguration=                  MyImageFileDirectory.getPlanarConfiguration;
                FieldsForImageReading.Compression=                          MyImageFileDirectory.getCompressionType;



        end
        
    end

    methods (Access = private)

         function [Compression] = getComp(obj, CurrentImageStructure)

             switch CurrentImageStructure.Directory.Compression   
                    case 'Uncompressed'
                        Compression = 'NoCompression';

                    otherwise
                        error('Only uncompressed images supported.')
                    
             end

         end
    


    end
    
    methods (Access = private) % GETTERS METADATA

         function MetaData =         getMetaDataInternal(obj)
 
                ImageSegments =                                     obj.getImageSegementsOfSelectedScenes;

                XDimensionData =                                    cellfun(@(x) x.Size, obj.getDimensionInfoFor(ImageSegments, 'X'));
                YDimensionData =                                    cellfun(@(x) x.Size, obj.getDimensionInfoFor(ImageSegments, 'Y'));
                ZDimensionData =                                    cellfun(@(x) x.Start, obj.getDimensionInfoFor(ImageSegments, 'Z')) + 1;
                TDimensionData =                                    cellfun(@(x) x.Start, obj.getDimensionInfoFor(ImageSegments, 'T')) + 1;
                CDimensionData =                                    cellfun(@(x) x.Start, obj.getDimensionInfoFor(ImageSegments, 'C')) + 1;

                MetaData.EntireMovie.NumberOfRows=                  max(XDimensionData);
                MetaData.EntireMovie.NumberOfColumns=               max(YDimensionData);
                MetaData.EntireMovie.NumberOfPlanes=                max(ZDimensionData);
                MetaData.EntireMovie.NumberOfTimePoints=            max(TDimensionData);
                MetaData.EntireMovie.NumberOfChannels=              max(CDimensionData);

                ScalingString =                                    PMXML(obj.getMetaDataString).getElementContentsWithTitle('Scaling' ); 
                DistanceStrings =                                  PMXML(ScalingString{1,1}).getElementContentsWithTitle('Distance' ); 
                Values =                                           cellfun(@(x) str2double(PMXML(x).getElementContentsWithTitle('Value')),  DistanceStrings); 
                
                MetaData.EntireMovie.VoxelSizeX=                   Values(1); 
                MetaData.EntireMovie.VoxelSizeY=                   Values(2);  
                if length(Values) == 3
                    MetaData.EntireMovie.VoxelSizeZ =              Values(3);  
                else
                    MetaData.EntireMovie.VoxelSizeZ=               1e-6; 
                end

                 MetaData.TimeStamp =               obj.getTimeStampsFromSegmentList;
                 MetaData.RelativeTimeStamp =       MetaData.TimeStamp- MetaData.TimeStamp(1);

         end
        
         function TimeStamps =      getTimeStampsFromSegmentList(obj)
            Attachmenets =          obj.SegmentList(cellfun(@(x) contains(x, 'ZISRAWATTACH'), obj.SegmentList(:,1)),:);
            Entries =               cellfun(@(x) x.AttachmentEntryA1, Attachmenets(:,6),  'UniformOutput', false);
            Row =                   cellfun(@(x) contains(x.ContentFileType', 'CZTIMS'), Entries);
            TimeStamps =            cell2mat(Attachmenets{Row, 6}.Data.TimeStamps);

          end
        
         

    end

    methods (Access = private) % GETTERS SEGMENTS
        
         function segmentList =     getSegments(obj)
            %GETSEGMENTS returns segment-information of czi file
            
            obj.FilePointer =            obj.getPointer;
            if obj.FilePointer == -1
                error('Cannot access file. %s Segment retrieval interrupted.', obj.FileName)
                
            end

            counter = 0;
            
            while true %% go through one segment after another (until reaching eof);
               
                counter = counter + 1;
                segmentList(counter, 1 : 5) = obj.getSegmentDescription;
                
                if feof(obj.FilePointer)
                    break
                end
              
                if contains(segmentList{counter, 1}, 'ZISRAWFILE')
                    segmentContent = obj.getSegmentHeader;
                   
               elseif contains(segmentList{counter, 1}, 'ZISRAWDIRECTORY')
                   segmentContent = obj.getDirectoryEntries;
                     
                elseif contains(segmentList{counter, 1}, 'ZISRAWATTDIR')
                    segmentContent = obj.getAttachmentsDirectory;
                     
                elseif contains(segmentList{counter, 1}, 'ZISRAWMETADATA')
                    segmentContent = obj.getRawMetaData(segmentList{counter, 2});
                       
                elseif contains(segmentList{counter, 1}, 'ZISRAWSUBBLOCK')
                     segmentContent = obj.getImageSubBlock(segmentList{counter, 3});

                elseif contains(segmentList{counter, 1}, 'ZISRAWATTACH')
                    segmentContent = obj.getNamedAttachment;
                    
                else 
                    segmentContent = 'Content could not be parsed.';
                
                end
                
                  segmentList{counter,6} =    segmentContent;
                  clear content
                  fseek(obj.FilePointer, segmentList{counter, 3} + segmentList{counter, 4}, 'bof'); % jump to beginning of next segment;
                

            end
            
            fclose(obj.FilePointer);
            
          end
       
         function segement =        getSegmentDescription(obj)
                offsetHeaderStart =         ftell(obj.FilePointer);
                ReadSegmentID =             fread(obj.FilePointer, 16, '*char')'; % segment ID, up to 16 characters
                AllocatedSize =             fread(obj.FilePointer, 1, '*uint64');
                UsedSize =                  fread(obj.FilePointer, 1, '*uint64');
                offsetDataStart =           ftell(obj.FilePointer); % get current position; this is at the end of the SegmentHeader;

                segement{1, 1} =            ReadSegmentID;
                segement{1, 2} =            offsetHeaderStart;
                segement{1, 3} =            offsetDataStart;
                segement{1, 4} =            AllocatedSize;
                segement{1, 5} =            UsedSize;
         end
       
         function content =         getSegmentHeader(obj)
            content.major =              fread(obj.FilePointer, 1, '*uint32');
            content.minor =              fread(obj.FilePointer, 1, '*uint32');
            fseek(obj.FilePointer, 8, 'cof');
            content.primaryFileGuid =    fread(obj.FilePointer, 2, '*uint64');
            content.fileGuid =           fread(obj.FilePointer, 2, '*uint64');
            content.filePart =           fread(obj.FilePointer, 1, '*uint32');
            content.dirPos =             fread(obj.FilePointer, 1, '*uint64');
            content.mDataPos =           fread(obj.FilePointer, 1, '*uint64');
            fseek(obj.FilePointer, 4, 'cof');
            content.attDirPos  =         fread(obj.FilePointer, 1, '*uint64');
        end
        
    end
    
    methods (Access = private) % GETTERS SEGMENTS: DIRECTORY-ENTRIES;
       
        function content =          getDirectoryEntries(obj)
               content.EntryCount =         fread(obj.FilePointer,1, '*uint32');
                fseek(obj.FilePointer, 124, 'cof');
                for directoryIndex = 1:content.EntryCount
                         content.Entries{directoryIndex,1} =                    obj.ReadDirectoryEntries;
                end
        end
        
        function DirectoryEntry =   ReadDirectoryEntries(obj)

                    DirectoryEntry.SchemaType =             fread(obj.FilePointer, 2, '*char');
                    pixelTypeNumber =                       fread(obj.FilePointer, 1, '*uint32');
                    DirectoryEntry.PixelType =              obj.convertIndexToPixelType(pixelTypeNumber);
                    DirectoryEntry.FilePosition =           fread(obj.FilePointer, 1, '*uint64');
                    DirectoryEntry.FilePart =               fread(obj.FilePointer, 1, '*uint32');

                    compressionNumber =                     fread(obj.FilePointer, 1, '*uint32');
                    DirectoryEntry.Compression =            obj.convertIndexToCompressionType(compressionNumber);
                    DirectoryEntry.PyramidType =            fread(obj.FilePointer, 1, '*uint8');
                   
                    fseek(obj.FilePointer, 5, 'cof');           % skip spare bytes
                    DirectoryEntry.DimensionCount =        fread(obj.FilePointer, 1, '*uint32');
                    
                    
                    DimensionEntryDV1 =         cell(DirectoryEntry.DimensionCount,1);
                     
                    for index = 1 : DirectoryEntry.DimensionCount
                        DimensionEntryDV1{index,1} =   obj.readDirectoryEntry;
                    end
                    
                    DirectoryEntry.DimensionEntries =  DimensionEntryDV1;

            end
                     
        function pixType =          convertIndexToPixelType(obj, index)

            switch index
                case 0
                    pixType = 'Gray8';
                case 1
                    pixType = 'Gray16';
                case 2
                    pixType = 'Gray32Float';
                case 3
                    pixType = 'Bgr24';
                case 4
                    pixType = 'Bgr48';
                case 8
                    pixType = 'Bgr96Float';
                case 9
                    pixType = 'Bgra32';
                case 10
                    pixType = 'Gray64ComplexFloat';
                case 11
                    pixType = 'Bgr192ComplexFloat';
                case 12
                    pixType = 'Gray32';
                case 13
            pixType = 'Gray64';
            end

        end
        
        function compType =         convertIndexToCompressionType(obj,index)

            if index >= 1000
                compType = 'System-RAW';
            elseif index >= 100 && index < 999
                compType = 'Camera-RAW';
            else 
                switch index
                    case 0
                        compType = 'Uncompressed';
                    case 1
                        compType = 'JPEG';
                    case 2
                        compType = 'LZW';
                    case 4
                        compType = 'JPEG-XR';
                end

            end

        end
        
        function Entry =            readDirectoryEntry(obj)
            Entry.Dimension =               fread(obj.FilePointer, 4, '*char');
            Entry.Start =                   fread(obj.FilePointer, 1, '*int32');
            Entry.Size =                    fread(obj.FilePointer, 1, '*int32');
            Entry.StartCoordinate =         fread(obj.FilePointer, 1, '*float32');
            Entry.StoredSize =              fread(obj.FilePointer, 1, '*int32');

        end
            
        
    end
    
    methods (Access = private) % GETTERS SEGMENTS: ATTACHMENTS-ENTRIES;
        
        function content =              getAttachmentsDirectory(obj) 
                     content.EntryCount =         fread(obj.FilePointer,1, '*uint32');
                    fseek(obj.FilePointer, 252, 'cof');
                    for directoryIndex = 1 : content.EntryCount
                             content.Entries{directoryIndex,1} =                    obj.ReadAttachmentEntryA1;
                        
                    end
                   
        end
        
        function AttachmentEntry =      ReadAttachmentEntryA1(obj)
            
            AttachmentEntry.SchemaType =                fread(obj.FilePointer, 2, '*char'); %2
            fseek(obj.FilePointer, 10, 'cof');                                                 %10
            AttachmentEntry.FilePosition =              fread(obj.FilePointer, 1, '*uint64'); %8
            AttachmentEntry.FilePart =                  fread(obj.FilePointer, 4, '*int8'); %4
            AttachmentEntry.ContentGuid =               fread(obj.FilePointer, 2, '*uint64'); %16
            AttachmentEntry.ContentFileType =           fread(obj.FilePointer, 8, '*char'); %8
            AttachmentEntry.Name =                      fread(obj.FilePointer, 80, '*char'); %80

        end
  
    end
    
    methods (Access = private) % GETTERS SEGMENTS: RAW META-DATA;

        function content =          getRawMetaData(obj, offsetHeaderStart)
                    size =                      fread(obj.FilePointer, 1, '*uint32');
                    fseek(obj.FilePointer, offsetHeaderStart + 256, 'bof');
                    content =                    fread(obj.FilePointer, size, '*char')';
        end
        
        
        
    end
    
    methods (Access = private) % GETTERS SEGMENTS: IMAGE SUB-BLOCK;

         function content = getImageSubBlock(obj, offsetDataStart)
            
            content.MetadataSize =          fread(obj.FilePointer, 1, '*uint32');
            content.AttachmentSize =        fread(obj.FilePointer, 1, '*uint32');
            content.DataSize =              fread(obj.FilePointer, 1, '*uint64');
            content.Directory =                 obj.ReadDirectoryEntries;

            %% other content:
            DirectoryEntrySize =                32 + content.Directory.DimensionCount * 20;
            content.OffsetForMetaData =     offsetDataStart + max(256, DirectoryEntrySize + 16);
            content.OffsetForData =         content.OffsetForMetaData + content.MetadataSize;
            content.OffsetForAttachments =  uint64(content.OffsetForMetaData) + uint64(content.MetadataSize) + content.DataSize;

            fseek(obj.FilePointer, content.OffsetForMetaData, 'bof');
            content.MetaData =                  fread(obj.FilePointer, content.MetadataSize, '*char')';

            fseek(obj.FilePointer, content.OffsetForAttachments, 'bof');
            content.Attachment =                  fread(obj.FilePointer, content.AttachmentSize, '*char')';
            
        end
       
        
    end
    
    methods (Access = private) % GETTERS SEGMENTS: NAME ATTACHEMENT;

        function content =      getNamedAttachment(obj)
            
            content.DataSize =                          fread(obj.FilePointer, 1, '*uint32'); %4
            fseek(obj.FilePointer, 12, 'cof'); 
            content.AttachmentEntryA1 =                 obj.ReadAttachmentEntryA1;
            fseek(obj.FilePointer, 112, 'cof');      

                if contains(content.AttachmentEntryA1.ContentFileType', 'CZEVL')
                    content.Data = obj.getEventListData;
                    

                elseif contains(content.AttachmentEntryA1.ContentFileType', 'CZTIMS')
                    content.Data =       obj.getTimeStampListData;
                    
                end
            
            
            
        end
        
        function Data =         getEventListData(obj)
            Data.Size =                     fread(obj.FilePointer, 1, '*uint32');
            Data.NumberOfEvents =         fread(obj.FilePointer, 1, '*uint32');

             for eventIndex = 1:Data.NumberOfEvents
                Data.Event{eventIndex,1}.Size =               fread(obj.FilePointer, 1, '*uint32');
                Data.Event{eventIndex,1}.Time =               fread(obj.FilePointer, 1, 'double');
                Data.Event{eventIndex,1}.EventType =               fread(obj.FilePointer, 1, '*uint32');
                Data.Event{eventIndex,1}.DescriptionSize =               fread(obj.FilePointer, 1, '*uint32');
                Data.Event{eventIndex,1}.Description =               fread(obj.FilePointer, Data.Event{eventIndex,1}.DescriptionSize, '*char');
             end

        end
         
        function Data =         getTimeStampListData(obj)
            Data.Size =                     fread(obj.FilePointer, 1, '*uint32');
            Data.NumberTimeStamps =         fread(obj.FilePointer, 1, '*uint32');

            for timeIndex = 1:Data.NumberTimeStamps
                Data.TimeStamps{timeIndex,1} =               fread(obj.FilePointer, 1, 'double');
            end

            
        end

    end
    
    methods (Access = private) %% SETTERS: AdjustMetaDataByImageMap
                
        function obj =              AdjustMetaDataByImageMap(obj)
            
            myImageMap =    PMImageMap(obj.ImageMap);
            MaxPlanes =     myImageMap.getMaxPlaneForEachFrame;
            NoFit =         find(MaxPlanes ~= obj.getMaxPlaneFromMetaData);
           
            if length(NoFit) > 1
                 error('Cannot parse image directory.') % if the last frame is incomplete (only some planes captured) remove last frame; (same thing should be probably done for planes too;
        
            elseif length(NoFit) == 1 && NoFit == obj.getMaxFrameFromMetaData
                obj.MetaData.EntireMovie.NumberOfTimePoints = obj.getMaxFrameFromMetaData - 1;
                obj.MetaData.RelativeTimeStamp(end,:) = [];
                obj.MetaData.TimeStamp(end,:) = [];
                
                Rows = [false; myImageMap.getRowsForFrame(obj.getMaxFrameFromMetaData)];
                
                obj.ImageMap(Rows, :) = [];
                
            elseif isempty(NoFit)
                
            else
                error('Cannot parse image directory.')
                
                
            end
            
        end
        
        function rowMax =           getMaxRowFromMetaData(obj)
            % GETMAXROWFROMMETADATA return max row;
            % can be tricky when using image with multiple scences because this numbers is for the "entire" image;
            % for images with multiple scences it may be more meaningful to get max row for "individual" ;
            rowMax = str2double(PMXML(obj.getImageMetaData).getElementContentsWithTitle('SizeY'));
        end
        
        function myImageData =      getImageMetaData(obj)
            xmlParser =             PMXML(obj.getMetaDataString);
            imageData =             xmlParser.getElementContentsWithTitle('Image');
            assert(length(imageData) == 1, 'Can parse only single used objective.')
            myImageData =           imageData{1};
        end
        
        function rowMax =           getMaxColumnFromMetaData(obj)
            rowMax = str2double(PMXML(obj.getImageMetaData).getElementContentsWithTitle('SizeX'));
        end
        
        function rowMax =           getMaxPlaneFromMetaData(obj)
            rowMax = str2double(PMXML(obj.getImageMetaData).getElementContentsWithTitle('SizeZ'));
        end
        
        function rowMax =           getMaxFrameFromMetaData(obj)
            rowMax = str2double(PMXML(obj.getImageMetaData).getElementContentsWithTitle('SizeT'));
        end
        
        function rowMax =           getMaxChannelFromMetaData(obj)
            rowMax = str2double(PMXML(obj.getImageMetaData).getElementContentsWithTitle('SizeC'));
        end
     
        
    end

    methods (Access = private) % GETTERS: OBJECTIVE:

        function objectiveString =  getObjectiveString(obj)
            myString =                  obj.getMetaDataString;
            xmlParser =                 PMXML(myString);
            objectiveData =             xmlParser.getElementContentsWithTitle('Objectives');
            assert(length(objectiveData) == 1, 'Can parse only single used objective.')
            objectiveString =           objectiveData{1};
        end

        function Objective =        getObjectiveStructure(obj)

            objectiveString =                       obj.getObjectiveString;
            myXmlObject =                           PMXML(objectiveString);
            Keywords =                              {'LensNA'; 'NominalMagnification'; 'WorkingDistance'; 'PupilGeometry'; 'ImmersionRefractiveIndex'; 'Immersion'};
            Contents =                              cellfun(@(x) myXmlObject.getElementContentsWithTitle(x), Keywords);
            
            Objective.NumericalAperture =         str2double(Contents{1});
            Objective.Magnification =             str2double(Contents{2});
            Objective.WorkingDistance =           str2double(Contents{3});
            Objective.PupilGeometry =             Contents{4};
            Objective.ImmersionRefractiveIndex =  str2double(Contents{5});
            Objective.Immersion =                 Contents{6};

        end

        function Name =             getObjectiveName(obj)
            
            objectiveString =                       obj.getObjectiveString;
            [ AttributeNames, AttributeValues ] =   PMXML(objectiveString).getAttributesForElementKey('Objective');
            assert(length(AttributeNames) == 1, 'Cannot parse multiple inputs')
            MyAttributeName =                       AttributeNames{1};
            Index =                                 strcmp(MyAttributeName, 'Name');
            Name=                                   AttributeValues{1}{Index};

        end

        function Identifier =       getIdentifierForObjectiveName(obj, Name)

            myString =                  obj.getMetaDataString;
            pos = strfind(myString, ['<Objective Name="', Name]);
            if length(pos)== 1
                NewString =         myString(pos:end);
                Pos =               strfind(NewString, 'UniqueName');
                NewString =         NewString(Pos:end);
                Pos =               strfind(NewString , '"');
                Identifier =        NewString(Pos(1) + 1: Pos(2) - 1);
            else
                Identifier = 'Identifier not found.';
            end

        end



    end

end