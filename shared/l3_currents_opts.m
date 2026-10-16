function opts = l3_currents_opts(cfg)
% L3_CURRENTS_OPTS  Options for PUV_L3_currents from a deployment config.
%
%   opts = l3_currents_opts(cfg)
%
% opts.tideStation = cfg.tideStation (NOAA CO-OPS station id), or '' when the
% config does not set one. With '' PUV_L3_currents uses La Jolla 9410230 for a
% San Diego deployment and ERRORS anywhere else, so a new site cannot silently
% inherit a tide gauge 100+ km away.
%
% The two opt-in fallbacks (allowTtideFallback, allowNoTides) are never set
% from a config: they are for exploratory runs and must be passed by hand.
%
% Author: Holden Leslie-Bole, 2026

    opts = struct('tideStation', '');
    if isstruct(cfg) && isfield(cfg, 'tideStation') && ~isempty(cfg.tideStation)
        opts.tideStation = char(string(cfg.tideStation));
    end
end
