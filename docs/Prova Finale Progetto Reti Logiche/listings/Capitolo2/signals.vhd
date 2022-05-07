-- Counters                                         
signal bit_counter : std_logic_vector(7 downto 0);  
signal read_address : std_logic_vector(15 downto 0);
signal words_read : std_logic_vector(7 downto 0);   
-- Flags signals                                    
signal word_done : std_logic; 						
signal o_end : std_logic;							
signal enable : std_logic;							
-- Useful signals                                   
signal words_to_read : std_logic_vector(7 downto 0);
signal word : std_logic_vector (7 downto 0);		
signal message : std_logic;							
signal merged : std_logic_vector (15 downto 0); 	
signal state : std_logic_vector (1 downto 0);		