classdef PMTIFFOMEDocument
    %PMTIFFOMEDOCUMENT Takes care of special aspects of "OME" type TIFF file;
    % this object is typically used by PMTIFFDocument objects to help them interpret lsm files;
    
    
    properties (Access = private)
        
        ImageDescriptionDirectories
        
    end
    
    methods
        function obj = PMTIFFOMEDocument(varargin)
            %PMTIFFOMEDOCUMENT Construct an instance of this class
            %   takes 1 argument: image-file directories that contain image-description;
            switch length(varargin)
                
                case 1
                    obj.ImageDescriptionDirectories = varargin{1};
                    
                otherwise
                    error('Wrong input.')
                
                
            end
            
            
        end
        
       
    end
    
    methods % GETTERS
       
         function MetaData =            getMetaData(obj)
             % GETMETADATA returns meta-data structure
            
                ParsedOMEMetaData =                      obj.ExtractOMESpecificMappingData;
                  
                FirstRowForDimensionsName=                                      ParsedOMEMetaData.name_pixels(1,:);
                FirstRowForDimensionsValues=                                    ParsedOMEMetaData.value_pixels(1,:);

                ColumnForVoxelSizeX=                                            strcmp(FirstRowForDimensionsName, 'PhysicalSizeX');
                VoxelSizeX=                                                     str2double(FirstRowForDimensionsValues{ColumnForVoxelSizeX})/10^6; % convert to m

                ColumnForVoxelSizeY=                                            strcmp(FirstRowForDimensionsName, 'PhysicalSizeY');
                VoxelSizeY=                                                     str2double(FirstRowForDimensionsValues{ColumnForVoxelSizeY})/10^6; % convert to m

                ColumnForVoxelSizeZ=                                            strcmp(FirstRowForDimensionsName, 'PhysicalSizeZ');
                VoxelSizeZ=                                                     str2double(FirstRowForDimensionsValues{ColumnForVoxelSizeZ})/10^6; % convert to m

                ColumnForNumberOfChannels=                                      strcmp(FirstRowForDimensionsName, 'SizeC');
                NumberOfChannels=                                               str2double(FirstRowForDimensionsValues{ColumnForNumberOfChannels});

                ColumnForNumberOfColumns=                                       strcmp(FirstRowForDimensionsName, 'SizeX');
                NumberOfColumns=                                                str2double(FirstRowForDimensionsValues{ColumnForNumberOfColumns});

                ColumnForNumberOfRows=                                          strcmp(FirstRowForDimensionsName, 'SizeY');
                NumberOfRows=                                                   str2double(FirstRowForDimensionsValues{ColumnForNumberOfRows});

                ColumnForSizeZ=                                                 strcmp(FirstRowForDimensionsName, 'SizeZ');
                NumberOfPlanes=                                                 str2double(FirstRowForDimensionsValues{ColumnForSizeZ});

                % ColumnForSizeT=                                               strcmp(FirstRowForDimensionsName, 'SizeT');
                NumberOfFrames=                                                 size(ParsedOMEMetaData.AcquisitionDates,1);

                ListWithDates=                                                  ParsedOMEMetaData.AcquisitionDates;
                ListWithDates_Reformatted=                                      cellfun(@(x) [ x(1:10) ' ' x(12:end)], ListWithDates, 'UniformOutput', false);
                ListWithAbsoluteTimeStamps_Sec=                                 cell2mat(cellfun(@(x) datenum(x)*3600*24, ListWithDates_Reformatted, 'UniformOutput', false));


                 metaDataObject =            PMMetaData( ...
                                                    NumberOfRows,...
                                                    NumberOfColumns, ...
                                                    NumberOfPlanes, ...
                                                    NumberOfFrames, ...
                                                    NumberOfChannels, ...
                                                    VoxelSizeX, ...
                                                    VoxelSizeY, ...
                                                    VoxelSizeZ, ...
                                                    ListWithAbsoluteTimeStamps_Sec ...
                                                    );

                MetaData =                  metaDataObject.getMetaDataStructure;

               
         end
        
         function OrderOfImages =       getImageOrderMatrix(obj)
             % GETIMAGEORDERMATRIX returns matrix with order of frames, planes, and channels of image-file directories;
            
            
                ParsedOMEMetaData =                     obj.ExtractOMESpecificMappingData;
                MetaDataInternal =                      obj.getMetaData;
                ContentOfAllImageDescriptionFields =    obj.ImageDescriptionDirectories;

                [ name_ome, value_ome ] =                cellfun(@(x) XML_GetAttributes( x,  'OME'), ContentOfAllImageDescriptionFields, 'UniformOutput', false);

                %  [ name_ome, value_ome ] =                cellfun(@(x) XML_GetAttributes( x,  'OME'), ImageDescriptionEntries, 'UniformOutput', false);

                name_ome=                               vertcat(name_ome{:});
                name_ome=                               vertcat(name_ome{:});
                
                value_ome=                              vertcat(value_ome{:});
                value_ome=                              vertcat(value_ome{:});
             
                ListWithCorrectRows=                    strcmp(name_ome, 'UUID');
                
                ListWithFileNamesInOMEHeader=           ParsedOMEMetaData.uuid_contents;
                ListWithFileNamesInEachIFD=             value_ome(ListWithCorrectRows);
                
                ListWithMatchedFileNames=               [ListWithFileNamesInOMEHeader ListWithFileNamesInEachIFD];
                
                CompareIFDHeaderAndEachIFDFileName= strcmp(ListWithMatchedFileNames(:,1), ListWithMatchedFileNames(:,2));
                
                if min(CompareIFDHeaderAndEachIFDFileName)==0
                    input('Not all filenames of individual IFDs match. Do you want to continue?')
                end

                %% get matrix that specifices where in the images-sequence the read files should be placed:
                NumberOfFrames=                         MetaDataInternal.EntireMovie.NumberOfTimePoints;
                NumberOfPlanes=                         MetaDataInternal.EntireMovie.NumberOfPlanes;
                NumberOfChannels=                       MetaDataInternal.EntireMovie.NumberOfChannels;
                
                % timeframes need to be reconstructed because they are not explictly written down in Prairie-OME;
                ListWithTimeFrames =                    1 : NumberOfFrames;
                ListWithTimeFramesForAllIFD =           repmat(ListWithTimeFrames, NumberOfPlanes * NumberOfChannels, 1);
                ListWithTimeFramesForAllIFD=            reshape(ListWithTimeFramesForAllIFD, numel(ListWithTimeFramesForAllIFD), 1);
                
                OrderOfImages(:,3)=                     str2double(ParsedOMEMetaData.value_tiff(:,1)) + 1;   % channel
                OrderOfImages(:,2)=                     str2double(ParsedOMEMetaData.value_tiff(:,3)) + 1;      % Z;      
                OrderOfImages(:,1)=                     ListWithTimeFramesForAllIFD;
                
            
               
            
         end
   
    end
    
    methods (Access = private)  % GETTERS
       
        function ParsedOMEMetaData =           ExtractOMESpecificMappingData(obj)

            
                   MetaDataString = obj.getMetaDataString;
                   
                    %% parse OME-XML field:
                    StartPositions=                     (strfind(MetaDataString, '<Image'))';
                    EndPositions=                       (strfind(MetaDataString, '</Image>'))';

                    ImageElements_EachTimeFrame=       arrayfun(@(start, stop) MetaDataString(start : stop), StartPositions, EndPositions, 'UniformOutput', false);

                    [ name_pixels, value_pixels ] =     cellfun(@(x) XML_GetAttributes( x,  'Pixels'), ImageElements_EachTimeFrame, 'UniformOutput', false);
                    [ name_tiff, value_tiff ] =         cellfun(@(x) XML_GetAttributes( x,  'TiffData'), ImageElements_EachTimeFrame, 'UniformOutput', false);
                    [ uuid_contents ] =                 cellfun(@(x) XML_GetElementContents( x, 'UUID' ), ImageElements_EachTimeFrame, 'UniformOutput', false);
                    [AcquisitionDates]=                 cellfun(@(x) XML_GetElementContents( x, 'AcquisitionDate' ), ImageElements_EachTimeFrame, 'UniformOutput', false);


                    
                    
                    %% extract from time-frame cells:
                    uuid_contents=                 vertcat(uuid_contents{:});
                    AcquisitionDates=              vertcat(AcquisitionDates{:});

                    
                    
                    %% extract from time-frame cells cell (two times)
                    value_tiff=                                                 vertcat(value_tiff{:});
                    name_tiff=                                                  vertcat(name_tiff{:});

                    value_tiff=                                                 vertcat(value_tiff{:});
                    name_tiff=                                                  vertcat(name_tiff{:});

                    name_pixels=                                                vertcat(name_pixels{:});
                    value_pixels=                                               vertcat(value_pixels{:});

                    name_pixels=                                                vertcat(name_pixels{:});
                    value_pixels=                                               vertcat(value_pixels{:});

                    ParsedOMEMetaData.uuid_contents=                            uuid_contents;
                    ParsedOMEMetaData.AcquisitionDates=                         AcquisitionDates;

                    ParsedOMEMetaData.value_tiff=                               value_tiff;
                    ParsedOMEMetaData.name_tiff=                                name_tiff;

                    ParsedOMEMetaData.name_pixels=                              name_pixels;
                    ParsedOMEMetaData.value_pixels=                             value_pixels;
           end
        
        function MyMetaDataString =             getMetaDataString(obj)    
             MyMetaDataString =                    obj.ImageDescriptionDirectories{1,1};
        end
         
    end
end

