classdef PMImageFiles
    %PMIMAGEFILES get image-map, meta-data etc., for a series of image-files;
    %   To extract image data from file;
    % supports '.tif', '.lsm', '.czi' and '.pic'
    
    properties (Access = private)
        FilePaths
        myImageDocuments
        
    end
    
    methods % initialize
        
          function obj = PMImageFiles(varargin)
                %PMIMAGEFILES Construct an instance of this class
                % takes 1 or 2 arguments:
                % 1: cell-string with paths of image files;
                % 2: index of wanted scence (numeric scalar or empty);

                NumberOfArguments = length(varargin);
                switch NumberOfArguments
                    case 1
                        obj.FilePaths =     varargin{1};
                        obj =               obj.SetImageDocuments;
                        
                    case 2
                        obj.FilePaths =     varargin{1};
                        obj =               obj.SetImageDocuments(varargin{2});
                        
                    otherwise
                        error('Wrong input.')

                end
          end
          
          function obj = set.FilePaths(obj, Value)
                assert(isvector(Value) && iscellstr(Value), 'Wrong input.')
                obj.FilePaths = Value; 
                
          end
        
        
    end
    
    methods % GETTERS TIFF
        
        function value =            getTIFFImageFileDirectoryContents(obj)
            
            assert( strcmp(obj.getFileType, 'tif'), 'Only supported for TIFF files.')
            value = arrayfun(@(x) x.getImageFileDirectoryContents, obj.myImageDocuments, 'UniformOutput', false);
            
        end
      
    end
    
    methods % GETTERS
        
        function documents = getImageFileDocuments(obj)
            documents = obj.myImageDocuments;
        end


        function value =            supportedFileType(obj)
               % SUPPORTEDFILETYPE returns true when file-type is supported and false when image file-type is not supported;
                  FileType =      obj.getFileType;
                  if isempty(FileType)
                      value = false;
                  else
                      value = true;
                  end
              
            end
          
        function calibrations =     getSpaceCalibration(obj)
            MetaDataFromImage =         obj.getMetaData;
            calibrations =              PMSpaceCalibrationSeries(cellfun(@(x) PMMetaData(x).getPMSpaceCalibration, MetaDataFromImage));
        end
        
        function navigations =      getTimeCalibration(obj)
              MetaDataFromImage =       obj.getMetaData;
             navigations =              PMTimeCalibrationSeries(cellfun(@(x) PMMetaData(x).getPMTimeCalibration, MetaDataFromImage));
        end
        
        function Navigation =       getNavigation(obj)
              MetaDataFromImage =       obj.getMetaData;
              
             Navigation =               PMNavigationSeries(cellfun(@(x) PMMetaData(x).getPMNavigation, MetaDataFromImage));
        end
        
        function imagemaps =        getImageMapsPerFile(obj, varargin)
            
            switch length(varargin)    
                case 0
                      imagemaps =               arrayfun(@(x) x.getImageMap, obj.myImageDocuments, 'UniformOutput', false); 
                case 1
                     imagemaps =               arrayfun(@(x) x.getImageMap(varargin{:}), obj.myImageDocuments, 'UniformOutput', false); 
                otherwise
                    error('Wrong input.')
            end
            
        end
        
        function MetaDataString =   getMetaDataString(obj)

                switch obj.getFileType
                    case 'czi' 
                      
                        FirstMovie =                obj.myImageDocuments{1,1};
                        MetaDataString =            FirstMovie.getMetaDataString;
                        
                       
                     case {'tif'}
                        paths =             obj.getPathsOfImageFiles;
                        FirstMovie =        cellfun(@(x)  PMTIFFDocument(x), paths(1), 'UniformOutput', false);
                        MetaDataString=     FirstMovie{1}.getRawMetaData;

                    case {'lsm'} % do not store ;
                        [~, MetaDataString] =            obj.getMetaDataForLsm;

                    otherwise
                        MetaDataString =                                   obj.getMetaDataSummary;

                end
            
            
        end
        
        function Summary =          getMetaDataSummary(obj)

            fileType =                                           obj.getFileType;
            switch fileType
                case 'czi' 
                  
                        Summary =          obj.myImageDocuments(1,1).getObjectiveSummary;
                            ImageCaptureSummary = obj.myImageDocuments(1,1).getImageCaptureSummary;

                            Summary = [Summary; ImageCaptureSummary];

                 case {'tif'}
                     Summary =           'No meta data summary for tif available';

                case {'lsm'} % do not store ;
                    [Summary, ~] =            obj.getMetaDataForLsm;

                otherwise
                    Summary =       'No meta data for undefined image type available.';

            end


        end

        function atLeastOneRead =   notAllFilesCouldBeRead(obj)
            atLeastOneRead =          ~(min(arrayfun(@(x) x.getFileCouldBeAccessed, obj.myImageDocuments)) == true);
        end

        
    end
              
    
    methods (Access = private)
        
        function obj =                                  SetImageDocuments(obj, varargin)
            
            switch length(varargin)
               
                case 0
                    WantedScenes = '';
                case 1
                    WantedScenes = varargin{1};
                
            end
                    
                switch obj.getFileExtension
                    case {'.tif', '.lsm', '.TIFF'}
                          obj.myImageDocuments =                            cellfun(@(x)  PMTIFFDocument(x), obj.getPathsOfImageFiles);

                    case '.czi'
                         obj.myImageDocuments =                              cellfun(@(x)  PMCZIMetaData(x, WantedScenes), obj.getPathsOfImageFiles);

                    case '.pic'
                         obj.myImageDocuments =                             cellfun(@(x)  PMImageBioRadPicFile(x), obj.getPathsOfImageFiles);
                         
                    case '.mp4'
                        error('Mp4 not yet supported.')

                    otherwise % need to add pic
                        error('Format of image file not supported.')

                end

        end
        
        function myPaths =                              getPathsOfImageFiles(obj)
            myPaths = obj.FilePaths;
            
        end
        
        function Extension =                            getFileExtension(obj)
              [~,~,Extensions] =                                      cellfun(@(x) fileparts(x), obj.getPathsOfImageFiles, 'UniformOutput', false);
                Extension =                                             unique(Extensions);
                if isempty(Extension)
                    error('List of extension is empty. No valid files were entered')
                elseif length(Extension)>1
                    error('Distinct extensions in file list. This is not allowed. All files must have the same extension')
                end

             Extension =                                             Extension{1,1};      
          end
           
        function FileType =                             getFileType(obj)
            Extension =         obj.getFileExtension;
            switch Extension
                case '.tif'
                    FileType =        'tif';
                case '.lsm'
                    FileType =        'lsm';
                case '.czi'
                    FileType =        'czi';
                case '.pic'
                    FileType =        'unknown';
                otherwise 
                    FileType = '';
            end 
        end

        function MetaDataFromImage =                    getMetaData(obj)
               MetaDataFromImage =                 arrayfun(@(x) x.getMetaData, obj.myImageDocuments, 'UniformOutput', false);
              
          end
            
        function [metaDataSummary,MetaDataString] =     getMetaDataForLsm(obj)
             
            if isempty(obj.getPathsOfImageFiles)
                
                metaDataSummary{1,1} = 'Imaging files not connected. Could not retrieve metadata';
                MetaDataString = 'Imaging files not connected. Could not retrieve metadata';
            else
                  fileType =                                  obj.getFileType;
             switch fileType
                case 'lsm' 
                    
                    FirstMovie =                        obj.myImageDocuments{1,1};
                    MetaDataString =                    FirstMovie.getRawMetaData;
                    
                    [lsminf,scaninf,imfinf] =           cellfun(@(x) lsminfo(x), obj.getPathsOfImageFiles, 'UniformOutput',false);
                    metaDataSummary{1,1} =              ['Objective: ', lsminf{1, 1}.ScanInfo.ENTRY_OBJECTIVE];
                    metaDataSummary{2,1}  =              sprintf('Used laser sources (not track-specific):');
                    numberOfLasers =                    length( lsminf{1, 1}.ScanInfo.WAVELENGTH);
                    LaserString =  '';
                    
                    for laserIndex = 1:numberOfLasers
                        if iscell(lsminf{1, 1}.ScanInfo.WAVELENGTH)
                            NumberText = sprintf('%i, ', round(lsminf{1, 1}.ScanInfo.WAVELENGTH{laserIndex}));
                        else
                            NumberText = sprintf('%i, ', round(lsminf{1, 1}.ScanInfo.WAVELENGTH));
                        end
                         LaserString =  [LaserString , NumberText];
                    end
                    
                    LaserString(end-1:end) = [];
                    metaDataSummary  =      [metaDataSummary; LaserString];
                    metaDataSummary =       [metaDataSummary; 'Emission filters for each channel:'];
                    metaDataSummary =       [ metaDataSummary  ;(lsminf{1, 1}.ScanInfo.FILTER_NAME)'];
                    
                 otherwise
                     metaDataSummary = 'Meta data summary currently not supported for this format.';        
             end
                
                
            end
            
          
            
         end
          
        
    end
end

