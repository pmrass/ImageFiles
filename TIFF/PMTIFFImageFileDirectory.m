classdef PMTIFFImageFileDirectory
    %PMTIFFIMAGEFILEDIRECTORY Summary of this class goes here
    %   for convenient retrieval of contens of TIFF image file-directory;
    
    properties (Access = private)
        CurrentImageFileDirectory
    end
    
    methods
        
        function obj = PMTIFFImageFileDirectory(varargin)
            %PMTIFFIMAGEFILEDIRECTORY Construct an instance of this class
            %   Takes 1 argument:
            % 1: cell matrix with image-file directory contents:
            switch length(varargin)
                case 1
                    obj.CurrentImageFileDirectory = varargin{1};
                otherwise
                    error('Wrong input.')
                
            end
        end
        
    
          
          
          
          
        
        
    end
    
    methods % GETTERS OVERVIEW:
        
        function struct = getStructure(obj)
           
            struct.ImageWidth =         obj.getTotalColumns;
            struct.ImageLength =        obj.getTotalRows;
            struct.BitsPerSample =      obj.getBitsPerSample;
            struct.Compression =        obj.getCompressionType;
            struct.PhotometricInterpretation = obj.getPhotometricInterpretation;
            struct.StripOffsets =       obj.getStripOffsets;
            struct.RowsPerStrip =       obj.getRowsPerStrip;
            struct.StripByteCounts =    obj.getStripByteCounts;
            struct.XResolution =        obj.getXPixelsPerUnit;
            struct.YResolution =        obj.getYPixelsPerUnit;
            struct.ResolutionUnit =     obj.getResolutionUnit;
            
            
            
            
        end
        
        
    end
    
    methods % GETTERS BASIC;
       
        function Content =          getTotalColumns(obj)
        Content = obj.getContentForCode(256);         
        end

        function Content =          getTotalRows(obj)
        Content = obj.getContentForCode(257);   
        end

        function MyBitsPerSample =  getBitsPerSample(obj)
        % read bits per sample: (it could become tricky if multiple different bits per sample would be allowed: therefore insist they are all the same).
        BitsPerSample = obj.getContentForCode(258);   

        if length(BitsPerSample)>= 2
            Identical=                                              unique(BitsPerSample(1:end));
            assert(length(Identical)== 1, 'Cannot read this file. Reason: All samples must have identical bit number')
        end
        MyBitsPerSample =                           BitsPerSample(1);

        end

        function Compression =      getCompressionType(obj)

            switch obj.getContentForCode(259)

                case 1
                    Compression = 'NoCompression';

                case 5
                    Compression = 'LZW';

                otherwise
                    error('Compression not supported.')

            end


        end

        function Content =          getPhotometricInterpretation(obj)
        Content = obj.getContentForCode(262);   

        end 

        function Content =          getStripOffsets(obj)
            Content = obj.getContentForCode(273);   
        end

        function RowsPerStrip =     getRowsPerStrip(obj)

        RowsPerStrip = obj.getContentForCode(278);  

        if RowsPerStrip > obj.getTotalRows
            RowsPerStrip = obj.getTotalRows;
        end

        end

        function Content =          getStripByteCounts(obj)
            Content = obj.getContentForCode(279);  
        end

        function Content =          getXPixelsPerUnit(obj)
            Content = obj.getContentForCode(282);   

        end

        function Content =          getYPixelsPerUnit(obj)
        Content = obj.getContentForCode(283);   

        end

        function Unit =             getResolutionUnit(obj)

            switch obj.getContentForCode(296)

            case 1
                Unit = 'Arbitrary';

            case 2
                Unit = 'Inch';

            case 3
                 Unit = 'Centimeter';

            otherwise
                error('Invalid unit.')


            end

        end
        
        
        
    end
    
    methods % GETTERS RESOLUTION
 
        function PixelSize =    getXPixelSize(obj)
           
                 switch obj.getResolutionUnit
                     case 'Inch'
                         
                         PixelsPerUnit =        obj.getXPixelsPerUnit;
                         switch obj.getSoftWareName
                            
                             case 'IncuCyte 2021C (Essen.dll v20213.1.7936.24788)'
                                PixelsPerMicroMeter =      PixelsPerUnit(1) / 1e+9;
                                PixelSize =                1 / PixelsPerMicroMeter;
                                
                             otherwise
                                 PixelSize =      PixelsPerUnit(1);
                                
                         end
                        
                     otherwise
                         error('Unit not supported')
                     
                 end
                 
            
        end
        
        function Software =     getSoftWareName(obj)
            
             RowWithPlanarConfiguration=                                 find(cell2mat(obj.CurrentImageFileDirectory(:,1))== 305); %'PlanarConfiguration'
            if isempty(RowWithPlanarConfiguration)
                Software = 'Unknown';
            else
                  Software =            obj.CurrentImageFileDirectory{RowWithPlanarConfiguration,4};
            end
            Software(end) = [];
             
        end
        
        function PixelSize =    getYPixelSize(obj)
            
              switch obj.getResolutionUnit
                     case 'Inch'
                         PixelsPerUnit =        obj.getYPixelsPerUnit;
                          switch obj.getSoftWareName
                            
                             case 'IncuCyte 2021C (Essen.dll v20213.1.7936.24788)'
                              PixelsPerMicroMeter =      PixelsPerUnit(1) / 1e+9;
                                PixelSize =                1 / PixelsPerMicroMeter;
                                
                                  otherwise
                                 PixelSize =      PixelsPerUnit(1);
                                
                         end
                     otherwise
                         error('Unit not supported')
                     
                     
                 end
            
            
        end
        
    end
    
    methods % GETTERS: HOW ARE IMAGES STORED IN FILE
         
        function PlanarConfiguration =      getPlanarConfiguration(obj)
            %METHOD1 Summary of this method goes here
            %   Detailed explanation goes here
              RowWithPlanarConfiguration=                                 find(cell2mat(obj.CurrentImageFileDirectory(:,1))== 284); %'PlanarConfiguration'
            if isempty(RowWithPlanarConfiguration)
                PlanarConfiguration=                                    0;
            else
                PlanarConfiguration =                                   obj.CurrentImageFileDirectory{RowWithPlanarConfiguration,4};
            end
        end

        function SampleFormat =             getSampleFormat(obj)
                 
            % read SampleFormat of TIFF file
            RowWithSampleFormat=                                        find(cell2mat(obj.CurrentImageFileDirectory(:,1))== 339); %'SampleFormat'
            if isempty(RowWithSampleFormat)
                SampleFormat=                                           1;
            else
                SampleFormat =                                          obj.CurrentImageFileDirectory{RowWithSampleFormat,4};
            end
          end
          
        function MyPrecision =              getPrecision(obj)
              
            % read precision:
            switch( obj.getSampleFormat )

                case 1
                    MyPrecision =                  sprintf('uint%i',obj.getBitsPerSample);

                case 2
                    MyPrecision =                  sprintf('int%i', obj.getBitsPerSample);

                case 3

                    if ( obj.getBitsPerSample == 32 )
                        MyPrecision =  'single';

                    else
                        MyPrecision = 'double';
                    end

                otherwise
                    error('unsuported TIFF sample format %i', obj.getSampleFormat);

            end
              
          end
          
        function SamplesPerPixel =          getSamplesPerPixel(obj)
                 ListWithSamplesPerPixelRows=                                        find(cell2mat(obj.CurrentImageFileDirectory(:,1))== 277);
            if isempty(ListWithSamplesPerPixelRows)
                SamplesPerPixel=                          1;
            else
                SamplesPerPixel =                         obj.CurrentImageFileDirectory{ListWithSamplesPerPixelRows,4};
            end

              
          end
            
        function MyTargetChannelIndex =     getTargetChannels(obj)
              
             switch obj.getPlanarConfiguration

                case 0 
                   MyTargetChannelIndex = NaN;

                case 1
                   MyTargetChannelIndex = NaN;
                   
                case 2

                    assert(obj.getSamplesPerPixel == length(obj.getStripOffsets), 'Cannot read file. Reason: number of strips must be identical to number of samples per pixel')

                    MyTargetChannelIndex=                       (1 : obj.getSamplesPerPixel)';
                  
                otherwise

                    error('Chosen planar-configuration is not supported')

             end
              
          end
      
    end
    
    methods (Access = private)
        
        function Content = getContentForCode(obj, Code)
            
            Row=               cell2mat(obj.CurrentImageFileDirectory(:,1))== Code; %'ImageLength');
            Content =          obj.CurrentImageFileDirectory{Row,4};
        end
        
        
        
        
    end
end

