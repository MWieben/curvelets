function [resMat,resMatNames,numImPts] = getTifBoundary(coords,img,object,imgName,distThresh,fibKey,endLength,fibProcMeth)

% getTifBoundary.m - This function takes the coordinates from the boundary file, associates them with curvelets, and produces relative angle measures. 
% 
% Inputs:
%   coords - the locations of the endpoints of each line segment making up the boundary
%   img - the image being measured
%   object - a struct containing the center and angle of each measured curvelet, generated by the newCurv function
%   distThresh - number of pixels from boundary we should evaluate curvelets
%   boundaryImg - tif file with boundary outlines, must be a mask file
%   fibKey - list indicating the beginning of each new fiber in the object struct, allows for fiber level processing
%
% Output:
%   measAngs - all relative angle measurements, not filtered by distance
%   measDist - all distances between the curvelets and the boundary points, not filtered
%   inCurvsFlag - curvelets that are considered
%   outCurvsFlag - curvelets that are not considered
%   measBndry = points on the boundary that are associated with each curvelet
%   inDist = distance between boundary and curvelet for each curvelet considered
%   numImPts = number of points in the image that are less than distThresh from boundary
%   insCt = number of curvelets inside an epithelial region
%
%
% By Jeremy Bredfeldt, LOCI, Morgridge Institute for Research, 2013


%Note: a "curv" could be a curvelet or a fiber segment, depending on if CT or FIRE is used

imHeight = size(img,1);
imWidth = size(img,2);
sz = [imHeight,imWidth];

% figure(600);
% imshow(img);

% figure(500);
% hold on;
% for k = 1:length(coords)
%    boundary = coords{k};
%    plot(boundary(:,2), boundary(:,1), 'y', 'LineWidth', 2);
% end

%collect all fiber points
allCenterPoints = vertcat(object.center);
%collect all boundary points
% coords = vertcat(coords{2:end,1});
coords = vertcat(coords{1:end,1});

%collect all region points
linIdx = sub2ind(sz, allCenterPoints(:,1), allCenterPoints(:,2));

[idx_dist,dist] = knnsearch(coords,allCenterPoints); %closest point to a boundary
reg_dist = img(linIdx);


%YL: test the boundary association
% figure(1002);clf;set(gcf,'pos',[200 300 imWidth imHeight ]);
% plot(coords(:,2),coords(:,1),'k.'); axis ij
% axis([1 imWidth 1 imHeight ]);hold on

%[idx_reg,reg_dist] = knnsearch([reg_col,reg_row],allCenterPoints); %closest point to a filled in region

%Make a list of points in the image (points scattered throughout the image)
C = floor(imWidth/20); %use at least 20 per row in the image, this is done to speed this process up
[I, J] = ind2sub(size(img),1:C:imHeight*imWidth);
allImPoints = [I; J]';
%Get list of image points that are a certain distance from the boundary
[~,dist_im] = knnsearch(coords(1:3:end,:),allImPoints); %returns nearest dist to each point in image
%threshold distance
inIm = dist_im <= distThresh;
%count number of points
inPts = allImPoints(inIm);
numImPts = length(inPts)*C;
% numImPts = 0;


%process all curvs, at this point 
curvsLen = length(object);
nbDist = nan(1,curvsLen); %nearest boundary distance
nrDist = nan(1,curvsLen); %nearest region distance
nbAng = nan(1,curvsLen); %nearest boundary relative angle
epDist = nan(1,curvsLen); %distance to extension point intersection
epAng = nan(1,curvsLen); %relative angle of extension point intersection
measBndry = nan(curvsLen,2);

inCurvsFlag = ~logical(1:curvsLen);
outCurvsFlag = ~logical(1:curvsLen);

for i = 1:curvsLen
%for i = 1:50
    %disp(['Processing fiber ' num2str(i) ' of ' num2str(curvsLen) '.']);
    
    %-- inside region?
    nrDist(i) = reg_dist(i)==255|reg_dist(i)== 1; %YL: mask can be 1-0(matlab lab) or 255-0(ImageJ) 
    %-- distance to nearest epithelial boundary
    nbDist(i) = dist(i);
    %-- relative angle at nearest boundary point
    if dist(i) <= distThresh
%         if ~isempty(find(i == [581 582 593 595]))  % 3-2-G3
%            [nbAng(i), bPt] = GetRelAng([coords(:,2),coords(:,1)],idx_dist(i),object(i).angle,imHeight,imWidth,i);    % add i as an input argument for debug
%         end
%         if ~isempty(find(i == [152 224]))  % 5-2-G2
%            [nbAng(i), bPt] = GetRelAng([coords(:,2),coords(:,1)],idx_dist(i),object(i).angle,imHeight,imWidth,i);    % add i as an input argument for debug
%         end
%         if ~isempty(find(i == [84 184]))  % 7-1-G3
%            [nbAng(i), bPt] = GetRelAng([coords(:,2),coords(:,1)],idx_dist(i),object(i).angle,imHeight,imWidth,i);    % add i as an input argument for debug
%         end
   
        [nbAng(i), bPt] = GetRelAng([coords(:,2),coords(:,1)],idx_dist(i),object(i).angle,imHeight,imWidth,i);    % add i as an input argument for debug
    else
        nbAng(i) = 0;
        bPt = [0 0];
    end
    
    %-- extension point features
    [lineCurv orthoCurv] = getPointsOnLine(object(i),imWidth,imHeight,distThresh);
    [intLine, iLa, iLb] = intersect([lineCurv(:,2) lineCurv(:,1)],coords,'rows');
    if (~isempty(intLine))
        %get the closest distance from the curvelet center to the
        %intersection (get rid of the farther one(s)) 
        [idxLineDist, lineDist] = knnsearch(intLine,object(i).center);
        boundaryPtIdx = iLb(idxLineDist);
        %%tentatively turn the extension feature off
%         %-- extension point distance
%         epDist(i) = lineDist;
%         %-- extension point angle
%         [epAng(i) bPt1] = GetRelAng([coords(:,2),coords(:,1)],boundaryPtIdx,object(i).angle,imHeight,imWidth,i);
    else
        epDist(i) = 10000;%distThresh;  % no intersection
        epAng(i) = 0;
        bPt1 = [1 1];      % if no intersection set boundary to be [1 1]
    end  
    measBndry(i,:) = bPt;  % nearest boundary
%     measeBndry(i,:) = bPt1; % extenstion bounday
%%YL: test the boundary association
%        figure(202);  %plot the association line
%        plot([object(i).center(1,2) bPt(1,1)],[object(i).center(1,1) bPt(1,2)],'m'); hold on
%        %plot center point
%        plot(object(i).center(2),object(i).center(1),'y*');
%        axis ij

%     if (bPt(1) ~= 0) && (bPt(2) ~= 0)
%         %plot the association line
%         plot([object(i).center(1,2) bPt(1,1)],[object(i).center(1,1) bPt(1,2)],'m');
%         %plot center point
%         plot(object(i).center(2),object(i).center(1),'y*');
%     end
    
%     %plot boundary point and association line
%     if class == 1       
%         plot(boundaryPt(2),boundaryPt(1),'go');
%         plot([object(i).center(2) boundaryPt(2)],[object(i).center(1) boundaryPt(1)],'g');
%     elseif class == 2        
%         plot(boundaryPt(2),boundaryPt(1),'bo');
%         plot([object(i).center(2) boundaryPt(2)],[object(i).center(1) boundaryPt(1)],'b');
%     else        
%         plot(boundaryPt(2),boundaryPt(1),'ro');
%         plot([object(i).center(2) boundaryPt(2)],[object(i).center(1) boundaryPt(1)],'r');
%     end        
%    drawnow; %pause(0.001);
%    fprintf('epAng = %f, nbAng = %f, nrDist = %f, nbDist = %f\n', epAng(i), nbAng(i), nrDist(i), nbDist(i));
%    pause;
    
end %of for loop

resMat = [nbDist', ... %nearest dist to a boundary
          nrDist', ... %flag, 0 for outside boundary, 1 for inside boundary
          nbAng',  ... %nearest relative boundary angle
          epDist', ... %extension point distance
          epAng',  ... %extension point relative boundary angle
          measBndry];  %list of boundary points associated with fibers
resMatNames = {
    'nearestBoundDist', ...
    'nearestRegionDist', ...
    'nearestBoundAng', ...
    'extensionPointDist', ...
    'extensionPointAng', ...
    'bndryPtRow', ...
    'bndryPtCol'};

end %of main function

function [relAng, boundaryPt] = GetRelAng(coords,idx,fibAng,imHeight,imWidth,fnum)
    boundaryAngle = FindOutlineSlope([coords(:,2),coords(:,1)],idx);
    boundaryPt = coords(idx,:);
    
    if (boundaryPt(1) == 1 || boundaryPt(2) == 1 || boundaryPt(1) == imHeight || boundaryPt(2) == imWidth)
        %don't count fiber if boundary point is along edge of image
        tempAng = 0;
    else
        %--compute relative angle here--
        %There is a 90 degree phase shift in fibAng and boundaryAngle due to image orientation issues in Matlab.
        % -therefore no need to invert (ie. 1-X) circ_r here.
        tempAng = circ_r([fibAng*2*pi/180; boundaryAngle*2*pi/180]);
        tempAng = 180*asin(tempAng)/pi;
        %YL debug the NaN angle
       
        if isnan(tempAng)
           
            figure(1002),plot(coords(idx,1),coords(idx,2),'ro','MarkerSize',10)
            text(coords(idx,1),coords(idx,2),sprintf('%d',fnum));
            disp(sprintf('fiber %d relative angle is Nan, fibAng = %f, boundaryAngle = %f, idx_dist = %d',fnum,fibAng,boundaryAngle,idx))
           pause(3)
        end
    end
    
    relAng = tempAng;    
end
     
function [lineCurv orthoCurv] = getPointsOnLine(object,imWidth,imHeight,boxSz)
    center = object.center;
    angle = object.angle;
    slope = -tand(angle);
    %orthoSlope = -tand(angle + 90); %changed from tand(obj.ang) to -tand(obj.ang + 90) 10/12 JB
    intercept = center(1) - (slope)*center(2);
    %orthoIntercept = center(1) - (orthoSlope)*center(2);
    
    %[p1 p2] = getBoxInt(slope, intercept, imWidth, imHeight, center, boxSz);
    if isinf(slope)
        dist_y = 0;
        dist_x = boxSz;
    else
        dist_y = boxSz/sqrt(1+slope*slope);
        dist_x = dist_y*slope;
    end
    p1 = [center(2) - dist_y, center(1) - dist_x];
    p2 = [center(2) + dist_y, center(1) + dist_x];
    [lineCurv ~] = GetSegPixels(p1,p2);
    
    %Not using the orthogonal slope for anything now
    %[p1 p2] = getIntImgEdge(orthoSlope, orthoIntercept, imWidth, imHeight, center);
    %[orthoCurv, ~] = GetSegPixels(p1,p2);
    orthoCurv = [];
    
end
