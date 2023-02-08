----------------------------------------------------------------------------------
--
-- Progetto di Reti Logiche 2021/2022
-- Andrea Sanguineti, codice persona: 10739788, matricola: 936930
-- 
----------------------------------------------------------------------------------
library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use ieee.numeric_std.all;

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
signal r0_load, r1_load, r2_load : std_logic;
signal r1_sel, r2_sel : std_logic;
signal addr_sel : std_logic_vector (1 downto 0);
signal reg0, reg1, reg2 : unsigned (7 downto 0);
signal compute : std_logic;
signal last, done : std_logic;
type S is (S0, S1, S2, S3, S4, S5, S6, S7);
signal cur_state, next_state : S;
type C is (C0, C1, C2, C3);
signal cur_compute_state : C;

begin

    -- reg0 process
    process(i_clk, i_rst)
    begin
		if(i_rst = '1') then
			reg0 <= "00000000";
		elsif falling_edge(i_clk) and (r0_load = '1') then
            reg0 <= unsigned(i_data);
		end if;
    end process;
    
    -- reg1 process
    process(i_clk, i_rst)
    begin
		if(i_rst = '1') then
			reg1 <= "00000000";
		elsif rising_edge(i_clk) and (r1_load = '1') then
		    if r1_sel = '0' then
			    reg1 <= "00000000";
		    elsif r1_sel = '1' then
                reg1 <= reg1 + 1;
	        end if;
		end if;
    end process;
    
    --reg2 process
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then
            reg2 <= "00000000";
        elsif falling_edge(i_clk) and (r2_load = '1') then
            if(r2_sel = '0') then
                reg2 <= unsigned(i_data);
            elsif(r2_sel = '1') then           
                reg2 <= shift_left(reg2, 4);
            end if;
       end if;
    end process;
    
    -- cur_state process
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then
            cur_state <= S0;
        elsif rising_edge(i_clk) then
            cur_state <= next_state;
        end if;
    end process;  
    
    -- o_done process
    process(i_clk, i_rst)
    begin
        if(i_rst = '1') then
            o_done <= '0';
        elsif falling_edge(i_clk) then
            o_done <= done;
        end if;
    end process;  
    
    -- o_address process
    process(i_rst, addr_sel)
    begin
        if(i_rst = '1') then
            o_address <= "0000000000000000";
        else
            case addr_sel is
                when "00" => o_address <= "0000000000000000";
                when "01" => o_address <= std_logic_vector(resize(reg1 + 1, 16));
                when "10" => o_address <= std_logic_vector(resize((reg1 * 2) + 1000, 16));
                when "11" => o_address <= std_logic_vector(resize((reg1 * 2) + 1001, 16));
                when others => o_address <= "XXXXXXXXXXXXXXXX";
            end case;
        end if;
    end process;
   
    -- last_process
    process(reg0, reg1)
    begin 
        if reg1 = reg0 then
            last <= '1';
        else
            last <= '0';
        end if;
    end process;
    
    -- next_state process                 
    process(cur_state, i_start, last)
    begin
        next_state <= cur_state;
        case cur_state is
            when S0 =>
                if i_start = '1' then
                    next_state <= S1;
                end if;
            when S1 =>
                next_state <= S2;
            when S2 =>
                if last = '0' then
                    next_state <= S3;
                elsif last = '1' then
                    next_state <= S7;  
                end if; 
            when S3 =>
                next_state <= S4;
            when S4 =>
                next_state <= S5;
            when S5 =>
                next_state <= S6;
            when S6 =>
                if last = '0' then
                    next_state <= S3;
                elsif last = '1' then
                    next_state <= S7;  
                end if;   
            when S7 =>
                if i_start = '0' then
                    next_state <= S0;
                end if;
        end case;
    end process;
    
    -- signals process
    process(cur_state)
    begin
        r0_load <= '0';
        r1_load <= '0';
        r2_load <= '0';
        r1_sel <= '0';        
        r2_sel <= '0';
        addr_sel <= "00";
        compute <= '0';
        o_en <= '1';
        o_we <= '0';
        done <= '0';
        case cur_state is
            when S0 =>            
                o_en <= '0';
            when S1 =>
                r1_load <= '1';
            when S2 =>
                r0_load <= '1';
                addr_sel <= "01";
            when S3 =>
                addr_sel <= "01";
                r2_load <= '1';
                compute <= '1';    
            when S4 =>
                addr_sel <= "10";
                o_we <= '1';
                r2_load <= '1';
                r2_sel <= '1';
                compute <= '1';
            when S5 =>
                addr_sel <= "11";
                o_we <= '1';
                r1_load <= '1';
                r1_sel <= '1';
            when S6 =>
                addr_sel <= "01";
            when S7 =>
                done <= '1';
                o_en <= '0';
        end case;
    end process;   
    
    -- compute process
    process(i_clk, i_rst)    
        variable res : std_logic_vector(7 downto 0) := (others => '0');
        variable temp_compute_state : C;        
        variable x : integer range 1 to 7;
    begin
        if(i_rst = '1') then
            cur_compute_state <= C0;
        elsif rising_edge(i_clk) then
            if(compute = '1') then
                temp_compute_state := cur_compute_state;
                for i in 7 downto 4 loop
                    x := 2*i - 7; -- i: 7, 6, 5, 4 / x: 7, 5, 3, 1
                    case temp_compute_state is
                        when C0 =>
                            if reg2(i) = '0' then
                                res(x downto x - 1) := "00";
                            elsif reg2(i) = '1' then    
                                   temp_compute_state := C2;
                                res(x downto x - 1) := "11";
                            end if;
                        when C1 =>
                            if reg2(i) = '0' then
                                temp_compute_state := C0;
                                res(x downto x - 1) := "11";
                            elsif reg2(i) = '1' then    
                                temp_compute_state := C2;
                                res(x downto x - 1) := "00";
                            end if;
                        when C2 =>
                            if reg2(i) = '0' then
                                temp_compute_state := C1;
                                res(x downto x - 1) := "01";
                            elsif reg2(i) = '1' then    
                                temp_compute_state := C3;
                                res(x downto x - 1) := "10";
                            end if;
                        when C3 =>
                            if reg2(i) = '0' then
                                temp_compute_state := C1;
                                res(x downto x - 1) := "10";
                            elsif reg2(i) = '1' then
                                res(x downto x - 1) := "01";
                            end if;
                    end case;    
                end loop;
                o_data <= res;
                cur_compute_state <= temp_compute_state;
            elsif(last = '1') then
                cur_compute_state <= C0;
            end if;
        end if;
    end process;
end Behavioral;