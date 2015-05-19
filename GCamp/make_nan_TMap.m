function [ OccMap_smooth, TMap_nan ] = make_nan_TMap( OccMap, TMap )
%[ nan_occmap ] = make_nan_TMap( Occmap, TMap )
%   This function takes Occmap and TMap and assigned nans to all 0 values
%   in the Occmap so that you can plot the track as white using imagesc_nan
%   OccMap_smooth is a smoothed occupancy map, with zeros at points of zero
%   occupancy, TMap_nan is the same as TMap but with nans where 
%   OccMap_smooth = 0.

% Get sum of original occupancy map
Occsum = sum(OccMap(:));
% Set up smoothing
sm = fspecial('disk',6);
OccMap_smooth = imfilter(OccMap,sm); % apply smoothing

OccMap_smooth = OccMap_smooth.*Occsum./sum(OccMap_smooth(:)); % keep sum the same (might not be necessary)

TMap_nan = TMap;
TMap_nan(OccMap_smooth(:) == 0) = nan;

end

