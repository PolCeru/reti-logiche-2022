library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use IEEE.NUMERIC_STD.ALL;

entity project_reti_logiche is
    port (
        i_clk : in std_logic;
        i_rst : in std_logic;
        i_start : in std_logic;
        i_data : in std_logic_vector(7 downto 0);
        o_address : out std_logic_vector(15 downto 0);
        o_done : out std_logic;
        o_en : out std_logic;
        o_we : out std_logic;
        o_data : out std_logic_vector (7 downto 0)
    );
end project_reti_logiche;

architecture Behavioral of project_reti_logiche is
type state_type is(
                START, 								  	-- The initial state
                LENGTH_FETCH,                           -- The state in which the word length is fetched
                MEM_L_WAIT,								-- The state in which a clock cycle is waited (synchronous memory)
                WORD_FETCH,								-- The state in which the word is fetched
				MEM_W_WAIT,								-- The state in which a clock cycle is waited (synchronous memory)
                CONV_START,								-- The state in which convolution begins
                CONV_END,								-- The state in which convolution is finished
                WRITE_WAIT,								-- The state in which the result is written to memory
                START_WAIT								-- The state in which the 'reset' of i_start is waited
                );         
-- State signal
signal next_state : state_type; 					    -- The next state the machine must be in
-- Counters                                             
signal bit_counter : std_logic_vector(7 downto 0);      -- Counts up to which bit of the word has been serialized
signal read_address : std_logic_vector(15 downto 0);    -- Counts up to which address has been written in memory
signal words_read : std_logic_vector(7 downto 0);       -- Counts the number of words read so far
-- Flags signals                                        
signal word_done : std_logic; 						    -- It is set to 1 if the word has been fully encoded
signal o_end : std_logic;							    -- It is set to 1 if all words have been completely encoded
signal enable : std_logic;							    -- It is set to 1 when the encoding starts
-- Useful signals                                       
signal words_to_read : std_logic_vector(7 downto 0);    -- Number of words to read
signal word : std_logic_vector (7 downto 0);		    -- The word that needs to be encoded
signal message : std_logic;							    -- The bit that needs to be encoded
signal merged : std_logic_vector (15 downto 0); 	    -- Used to store the enconding result of the word(pk1, pk2 for every bit of the word)
signal state : std_logic_vector (1 downto 0);		    -- The state of the convolutional encoder machine

begin     
    process(i_clk, i_rst)
        
        begin
            if(i_rst = '1') then
                next_state <= START;
                o_address <= (others => '0');
                o_done <= '0';
                o_en <= '0';
                o_we <= '0';
                o_end <= '0';
				word <= (others => '0');
                word_done <= '0';
                enable <= '0';
				state <= "00";
                bit_counter <= (others => '0');
				words_read <= (others => '0');
				merged <= (others => '0');
				message <= '0';
				words_to_read <= (others => '0');
				read_address <= (0 => '1', others => '0');
            elsif (i_clk'event and i_clk = '1') then
                case next_state is
                    when START =>
                        if(i_start = '1') then
                            next_state <= LENGTH_FETCH;
							o_en <= '1';
							o_address <= (others => '0');
							read_address <= (0 => '1', others => '0');
							words_read <= (others => '0');
							o_done <= '0';
                            o_we <= '0';
                            enable <= '0';
                            message <= '0';
                            word_done <= '0';
                            bit_counter <= (others => '0');
                            o_end <= '0';
                            state <= "00";
                            word <= (others => '0');
						else
							next_state <= START;
							o_done <= '0';
							o_en <= '0';
							o_we <= '0';
							enable <= '0';
							message <= '0';
							word_done <= '0';
							bit_counter <= (others => '0');
							o_end <= '0';
							words_read <= (others => '0');
							state <= "00";
							word <= (others => '0');
							read_address <= (0 => '1', others => '0');
						end if;
					when LENGTH_FETCH =>
						next_state <= MEM_L_WAIT;
						words_read <= (others => '0');
						read_address <= (0 => '1', others => '0');
					when MEM_L_WAIT =>
						words_to_read <= i_data;
						next_state <= WORD_FETCH;
						o_address <= read_address;
						o_en <= '1';
						o_we <= '0';
						words_read <= (others => '0');
					when WORD_FETCH =>
						next_state <= MEM_W_WAIT;
					when MEM_W_WAIT =>
						next_state <= CONV_START;
						word <= i_data;
						o_en <= '0';
						o_address <= (0 => '1', others => '0');
						message <= word(7);
					when CONV_START =>
                        next_state <= CONV_START;
                        if (words_read = words_to_read) then
                             o_end <= '1';
                             word_done <= '1';
                        end if;
                        -- Convolutional logic
                        message <= word(7); 										-- Load the last bit in order to start the encoding
                        word(7 downto 1) <= word(6 downto 0); 						-- Shift the remaining bits
                        bit_counter <= bit_counter + 1;
                        --  If the word has been fully encoded, updates read address and the words read
                        if (word_done = '0' and bit_counter >= "00001000") then
                            word_done <= '1';
                            read_address <= read_address + "0000000000000001";
                            words_read <= words_read + "00000001";
                        end if; 
                        if (word_done = '0' and enable = '1') then
                            merged(1) <= state(0) xor message;						-- p1k output
                            merged(0) <= state(1) xor (state(0) xor message);		-- p2k output
                            merged(15 downto 2) <= merged(13 downto 0); 			-- Shift in order to make space for the new cycle
                            state <= state(1) + (message & "0");					-- Updates the state of the convolutional encoder machine
                            o_data <= merged(15 downto 8);
                        else
                            enable <= '1';
                        end if;
						if (word_done = '1') then
							next_state <= CONV_END;
							o_en <= '1';
							o_we <= '1';
							enable <= '0';
							if (words_read = words_to_read) then
									o_end <= '1';
							end if;
							word_done <= '0';
							bit_counter <= (others => '0');
							o_data <= merged(15 downto 8);
							-- Updates o_address in order to write in the right memory cell (since read_address starts from 2 it needs to be normalized)
							o_address <= "0000001111101000" + read_address - "0000000000000100" + read_address; -- o_address = 1000 + (ra - 2) * 2 
						end if;
					when CONV_END =>
						next_state <= WRITE_WAIT;
						o_data <= merged(7 downto 0);
						o_address <= "0000001111101000" + read_address - "0000000000000011" + read_address; -- o_address = 1000 + (ra - 1) * 2 + 1
					when WRITE_WAIT =>
						if(o_end <= '0') then
							next_state <= WORD_FETCH;
							o_en <= '1';
							o_we <= '0';
							o_address <= read_address;
						else
							next_state <= START_WAIT;
							o_en <= '0';
							o_we <= '0';
							o_done <= '1';
						end if;
					when START_WAIT =>
						if(i_start = '1') then
							next_state <= START_WAIT;
						else
							next_state <= START;
							o_done <= '0';
							o_en <= '0';
							o_we <= '0';
							word_done <= '0';
							o_end <= '0';
						end if;
                end case;    
            end if;
    end process;
end Behavioral;