function registry = deployment_registry()
% DEPLOYMENT_REGISTRY  Returns a map of deployment names to config functions.
%
%   registry = deployment_registry()
%
%   Usage:
%       reg = deployment_registry();
%       cfg = reg('TBR23')();   % returns TBR23 config struct
%       cfg = reg('SIO24A')();  % returns SIO Pier spring 2024 config
%
%   Deployment naming convention:
%     SITE + year(s) + optional season letter
%     TBR23    = Torrey Pines Beach Recovery 2023 campaign (Torrey Pines PUV
%                deployment; same site as TOR23W/TOR24S. Named for the campaign,
%                not the SITE+season convention — would otherwise be TOR23S.)
%     TOR23W   = Torrey winter 2023-24 (was part of NN24)
%     SOL23    = Solana winter 2023-24 (was part of NN24)
%     TOR24S   = Torrey spring 2024
%     TOR24W   = Torrey winter 2024-25
%     TOR25S   = Torrey spring 2025
%     SIO24A-C = SIO Pier 2024 (A=spring, B=summer, C=fall-winter)
%     SIO25A-E = SIO Pier 2025 (A-E chronological)
%     SOL24    = Solana winter 2024-25
%     SOL25A-B = Solana 2025 (A=spring, B=winter)
%     LPL23    = Los Penasquitos 2023-24
%     LPL24-25 = Los Penasquitos subsequent deployments
% Author: Holden Leslie-Bole, 2026

    registry = containers.Map();

    % --- Original configs (fully parameterized from DeploymentNotes) ---
    registry('TBR23')  = @TBR23_config;
    % Convention-consistent alias for the TBR23 Torrey Pines deployment (same
    % site/season as TOR23W/TOR24S). Both keys load the same config; cfg.name
    % stays 'TBR23', so outputs/cache and downstream (Paper_1) are unchanged.
    % TODO: a proper TBR23 -> TOR23S rename (cfg.name + folders + Paper_1) is a
    % separate coordinated cleanup — see docs/todo.md.
    registry('TOR23S') = @TBR23_config;   % alias -> TBR23
    registry('TOR23W') = @TOR23W_config;    % Nov 2023-Feb 2024, 6 instruments (was NN24 Torrey)
    registry('SOL23')  = @SOL23_config;     % Nov 2023-Jan 2024, 3 instruments (was NN24 Solana)

    % --- Torrey Pines (post-TBR23/NN24) ---
    registry('TOR24S') = @TOR24S_config;     % Feb-May 2024, 5 instruments
    registry('TOR24W') = @TOR24W_config;     % Nov 2024-Feb 2025, 4 instruments
    registry('TOR25S') = @TOR25S_config;     % Mar-Jun 2025, 3 instruments (7m needs .VEC export)

    % --- SIO Pier (single instrument per deployment) ---
    registry('SIO24A') = @() SIO_Pier_config('SIO24A');  % Mar-May 2024
    registry('SIO24B') = @() SIO_Pier_config('SIO24B');  % Jun-Jul 2024
    registry('SIO24C') = @() SIO_Pier_config('SIO24C');  % Oct-Dec 2024
    registry('SIO25A') = @() SIO_Pier_config('SIO25A');  % Jan-Mar 2025
    registry('SIO25B') = @() SIO_Pier_config('SIO25B');  % Apr-Jun 2025
    registry('SIO25C') = @() SIO_Pier_config('SIO25C');  % Jul-Aug 2025
    registry('SIO25D') = @() SIO_Pier_config('SIO25D');  % Sep-Nov 2025
    registry('SIO25E') = @() SIO_Pier_config('SIO25E');  % Dec 2025-Feb 2026

    % --- Solana Beach (post-NN24, single instrument) ---
    registry('SOL24')  = @() Solana_config('SOL24');     % Dec 2024-Feb 2025 (ENU)
    registry('SOL25A') = @() Solana_config('SOL25A');    % Mar-May 2025
    registry('SOL25B') = @() Solana_config('SOL25B');    % Dec 2025-Feb 2026

    % --- Los Penasquitos Lagoon (single instrument) ---
    registry('LPL23')  = @() LPL_config('LPL23');       % Dec 2023-Feb 2024
    registry('LPL24')  = @() LPL_config('LPL24');        % Dec 2024-Feb 2025 (ENU)
    registry('LPL25A') = @() LPL_config('LPL25A');       % Mar-Jun 2025 (ENU)
    registry('LPL25B') = @() LPL_config('LPL25B');       % Dec 2025-Feb 2026

    % --- Pre-2023 archive (recopied/) — Tier 1 (pipeline-ready) ---
    registry('CAT21A') = @CAT21A_config;                 % Catalina, Feb-Mar 2021 (CATISL03)
    registry('CAT21B') = @CAT21B_config;                 % Catalina, Aug 2021 (CATISL02)
    registry('RUBY22') = @RUBY22_config;                 % Ruby2D Torrey cross-shore array, Nov 2021-Mar 2022

    % --- Pre-2023 archive (recopied/) — Tier 2 (new sites) ---
    registry('IB18W')  = @IB18W_config;                  % Imperial Beach winter 2018-19 (Nov 2018-Mar 2019)
    registry('IB19S')  = @IB19S_config;                  % Imperial Beach spring 2019 (Mar 2019-Apr 2019)

end
