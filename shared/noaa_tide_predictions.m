function [tidetime, tidehgt] = noaa_tide_predictions(station, StartDatenum, EndDatenum)
% NOAA_TIDE_PREDICTIONS  Hourly NOAA CO-OPS tide predictions for one station.
%
%   [tidetime, tidehgt] = noaa_tide_predictions(station, StartDatenum, EndDatenum)
%
% station       NOAA CO-OPS station id, char (e.g. '9410230', La Jolla)
% Start/EndDatenum  MATLAB datenums, UTC
% tidetime      'yyyy-MM-dd HH:mm' UTC strings, as returned by the API (cellstr
%               or datetime, whatever webread's CSV parser gives)
% tidehgt       predicted water level, m, relative to the station's MSL datum
%
% Same request as the lab toolbox's getztide2.m (product 'predictions', datum
% 'msl', units metric, time_zone gmt, interval h, CSV) with the station as an
% argument instead of hardcoded to 9410230. With station '9410230' it is the
% request PUV_L3_currents made through getztide2 for every catalog L3 up to
% 2026-10-15. Unlike getztide2, a response without predictions is an error
% here, not a printed line and an empty result.
%
% Only harmonic ("R") stations return hourly predictions; a subordinate ("S")
% station returns "No Predictions data was found" (e.g. 9410092 Catalina
% Harbor). Station list:
%   https://api.tidesandcurrents.noaa.gov/mdapi/prod/webapi/stations.json?type=tidepredictions
%
% Author: Holden Leslie-Bole, 2026

    st = char(string(station));
    if isempty(regexp(st, '^[0-9A-Z]+$', 'once'))
        error('noaa_tide_predictions:station', 'not a NOAA station id: "%s"', st);
    end
    api = 'https://tidesandcurrents.noaa.gov/api/datagetter?';
    bd = datestr(StartDatenum, 'yyyymmdd HH:MM');
    ed = datestr(EndDatenum, 'yyyymmdd HH:MM');
    url = [api 'begin_date=' bd '&end_date=' ed ...
        '&station=' st '&product=predictions&datum=msl&units=metric' ...
        '&time_zone=gmt&interval=h&application=web_services&format=csv'];
    T = webread(url, weboptions('Timeout', 60));
    if ~istable(T) || ~all(ismember({'DateTime','Prediction'}, T.Properties.VariableNames)) || height(T) == 0
        error('noaa_tide_predictions:noData', ...
            'NOAA returned no hourly predictions for station %s, %s to %s', st, bd, ed);
    end
    tidetime = T.DateTime;
    tidehgt  = T.Prediction;
end
