psql parking <tables.sql 
psql --command="\copy parking_fact from parking_fact" parking
psql --command="\copy block_dimension from block_dimension" parking
psql --command="\copy regulation_dimension from regulation_dimension" parking
psql --command="\copy regulation_time_dimension from regulation_time_dimension" parking
