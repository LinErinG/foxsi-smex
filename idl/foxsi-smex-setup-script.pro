COMMON foxsi_smex_vars, foxsi_root_path, foxsi_data_dir, foxsi_name, foxsi_optic_effarea, foxsi_number_of_modules

; Set Path where foxsi-smex is
CD, Current=fs_location

; to minimize the chance of collisions all variables names must be start
; with foxsi_

foxsi_root_path = fs_location
foxsi_data_path = strmid(foxsi_root_path, 0, strlen(foxsi_root_path)-3) + 'data/'
foxsi_name = 'FOXSI-SMEX'
foxsi_number_of_telescope_modules = 3
foxsi_launch_date = '2020/06/01'

add_path, foxsi_root_path, /expand

print, 'FOXSI SMEX Ready to Go!'
