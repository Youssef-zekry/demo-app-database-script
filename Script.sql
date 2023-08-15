insert into public."user"(first_name, last_name, username, birthdate, mail, password, gender, mobile, address)
values
('John', 'Doe', 'johndoe', '1980-01-01', 'johndoe@example.com', 'password123', 'M', '555-1234', '123 Main St'),
('Jane', 'Doe', 'janedoe', '1985-02-01', 'janedoe@example.com', 'password456', 'F', '555-5678', '456 Maple Ave');

insert into public.balance (user_id,balance) values(1,5000)

CREATE OR REPLACE FUNCTION get_user_details(email character varying, password character varying)
    RETURNS TABLE (
        first_name VARCHAR,
        last_name VARCHAR,
        birthdate DATE,
        mail VARCHAR,
        gender CHAR,
        mobile VARCHAR,
        address VARCHAR,
        balance NUMERIC(10, 2)
    ) AS $$
BEGIN
    RETURN QUERY SELECT u.first_name, u.last_name, u.birthdate, u.mail, u.gender, u.mobile, u.address,b.balance
        FROM "user" u join "balance" b on u.user_id = b.user_id
        WHERE u.mail = $1 AND u.password = $2;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM get_user_details('johndoe@example.com', 'password123');

SELECT pg_terminate_backend(pid)
FROM pg_stat_activity
WHERE state = 'idle';


select * from public.user;










CREATE OR REPLACE FUNCTION get_user_details(user_id integer)
    RETURNS TABLE (
        first_name VARCHAR,
        last_name VARCHAR,
        birthdate DATE,
        mail VARCHAR,
        gender CHAR,
        mobile VARCHAR,
        address VARCHAR,
        balance NUMERIC(10, 2)
    ) AS $$
BEGIN
    RETURN QUERY SELECT u.first_name, u.last_name, u.birthdate, u.mail, u.gender, u.mobile, u.address,b.balance
        FROM "user" u join "balance" b on u.user_id = b.user_id
        WHERE u.user_id = get_user_details.user_id;
END;
$$ LANGUAGE plpgsql;

--select * from get_user_details(1);


CREATE OR REPLACE FUNCTION authenticate_user(mail character varying, password character varying)
    RETURNS integer as $$
   		declare user_id integer;
   	begin
   		select u.user_id into user_id from 
   			"user" u 
   		where u.mail = $1 and u.password = $2;
   	if found then return user_id;
   	else return -1;
   	end if;
   	end
   	$$ LANGUAGE plpgsql;

--select * from authenticate_user('johndoe@example.com', 'password123');
   
   
--  create type user_details_with_status as (
--   		status_code integer,
--        message varchar,
--        first_name VARCHAR,
--        last_name VARCHAR,
--        birthdate DATE,
--        mail VARCHAR,
--        gender CHAR,
--        mobile VARCHAR,
--        address VARCHAR,
--        balance NUMERIC(10, 2)
--  );
   
   
-- 16- authenticate user and get details
CREATE OR REPLACE FUNCTION api_login(email character varying, v_password character varying,
	   out status_code integer,
       out message varchar,
       out first_name VARCHAR,
       out last_name VARCHAR,
       out birthdate DATE,
       out mail VARCHAR,
       out gender CHAR,
       out mobile VARCHAR,
       out address VARCHAR,
       out balance NUMERIC(10, 2), 
       out userid integer,
       out token varchar)
     RETURNS record 
      AS $$
    DECLARE 
    	currenttime timestamp;
    	expiry timestamp;
        v_session_status text;
       	s_count int;
        u_count int;
   	begin
	   	
	   	select count(1) into u_count from "user" u
	   	where u.mail = email and u.password = v_password;
	   
   		if u_count = 1 then
   		
   			   select user_id into userid from "user" u where u.mail = email and u.password = v_password;

	   		message := 'success';
	   		currenttime := current_timestamp;
	   		expiry := current_timestamp + interval '30 Minutes';
	   		token := uuid_generate_v1();
	   		select count(1) into s_count from "session" s 
	   		where s.user_id = userid and s.session_status = 'active';
		
			 if s_count >= 1 
			 then 
			 	update "session" set session_status = 'inactive' where user_Id = userid and session_status = 'active'; 
	   		end if;
	   	
	   		insert into session(user_id, token, creation_time, expiry_time,session_status)
	   		values(userid, token, currenttime, expiry,'active');
	   	
   			select u.first_name, u.last_name, u.birthdate, u.mail, u.gender, u.mobile, u.user_id, u.address,b.balance
   			into first_name, last_name, birthdate, mail, gender, mobile, userid, address, balance
		        FROM "user" u join "balance" b on u.user_id = b.user_id
		        WHERE u.user_id = userid;
		      		       
		     status_code := 0;

   	else 
   		status_code := -1;
   		message := 'invalid username or password' ;
   	   	
   	end if;
   	end	
   	$$ LANGUAGE plpgsql;
--select * from "user" u where u.user_id = 3
--select * from api_login('janedoe@example.com','password456' );
--CREATE EXTENSION IF NOT EXISTS "uuid-ossp";  
--SELECT uuid_generate_v1();  
--select current_timestamp;
--
--    
--
--select * from "session" s where s.session_id = 40 and s.expiry_time > clock_timestamp() and s.session_status = 'active';
--
--select count(1) from "session" s where s.session_id = 41 and s.expiry_time > clock_timestamp() and s.session_status = 'active'; 
--
--select now();

-- 17- check session expiry
CREATE OR REPLACE FUNCTION is_expired(sessionid int, out expired boolean)
returns boolean
as $$
declare 
	s_count int;
begin 
	select count(1) into s_count from "session" s where s.session_id = sessionid and s.expiry_time > clock_timestamp() and s.session_status = 'active'; 
	if s_count >= 1
	 then 
		expired:= true;
	else 
		expired:= false;
	   		end if;
end
   	$$ LANGUAGE plpgsql;

   
--   select * from is_expired(42)

   
create table role(
		role_id serial primary key,
		role_name varchar(20) unique not null
);


insert into role (role_name) values ('admin'),('normal');

create table question(
		question_id serial primary key,
		question_name varchar(200) unique not null
);

alter table "user" add column question_id int not null default 1;

insert into question (question_name) values ('what city were you born in?'),('What is your oldest sibling’s middle name?');

-- 18- check ability to reset password
CREATE OR REPLACE FUNCTION is_able_toReset_password(email varchar, i_question_id int, i_answer varchar, out able boolean)
returns boolean
as $$
declare
	u_count int;
	user_answer varchar;
	q_id int;
begin
	select count(1) into u_count from "user" u where u.mail = email;

	   if u_count = 1 
	   then
   			   select answer into user_answer from "user" u where u.mail = email;
   			   select question_id into q_id from "user" u where u.mail = email;
   			  
   			  	if user_answer = i_answer and q_id = i_question_id
   			  	then
   			  		able := true;
   			  	else
   			  		able := false;
   			  	end if;
   		else
   			able := false;
   		end if;
   
end
   	$$ LANGUAGE plpgsql;
   
   	select  is_able_toReset_password('johndoe@example.com', 1, 'default value');
   
   
   
   -- 19- reset password
CREATE OR REPLACE FUNCTION reset_password(email varchar, i_question_id int, i_answer varchar, out status_code int, out message varchar)
returns record
as $$
declare
	u_count int;
	user_answer varchar;
	q_id int;
	r_id int;
	p_count int;
begin

	   if u_count = 1 
	   then
	    	select role_id into r_id from "user" u where u.mail = email;
   			select count(1) into p_count from role_privilege rp where rp.role_id = r_id and rp.privilege_id = 1;
   		
   			if p_count = 1
   			then
   			
   			   select answer into user_answer from "user" u where u.mail = email;
   			   select question_id into q_id from "user" u where u.mail = email;
   			  
   			  	if user_answer = i_answer and q_id = i_question_id and 
   			  	then
   			  		update "user" 
					set password = encode(gen_random_bytes(8), 'base64')
					where mail = email;
				
   			  		status_code := 0;
   			  		message := 'password has been reset';
   			  	else
   			  		status_code := -1;
   			  		message := 'failed to reset password';
   			  	end if;
	   		else
			  		status_code := -2;
			  		message := 'failed to reset password';
	   		end if;
   	else
		  		status_code := -3;
		  		message := 'failed to reset password';
   		end if;
   
end
   	$$ LANGUAGE plpgsql;
   
   
   
select  reset_password('johndoe@example.com', 1, 'default value');




   -- 20- get all products
CREATE OR REPLACE FUNCTION get_all_products()
returns table( product_id int,
		 product_name varchar(200),
		 product_desc varchar(200),
		 product_price float4,
		 stock int )
as $function$
begin
	return query select * from product;
end
   	$function$ LANGUAGE plpgsql;



select get_all_products();




create type my_type as (
		product_id	int,
		user_id int,
		item_count int
		);

select ('[{"product_id": 1, "user_id": 1, "item_count": 2},{"product_id": 2, "user_id": 1, "item_count": 2}]'::json#>'{1,user_id}'); 
	

DO $$
DECLARE
  json_element JSONB;
  j jsonb;
begin
	j = '[{"product_id": 1, "user_id": 1, "item_count": 2}, {"product_id": 2, "user_id": 1, "item_count": 2}]';
  FOR json_element IN SELECT jsonb_array_elements(j)
  LOOP
    RAISE NOTICE 'product_id: %, user_id: %, item_count: %', json_element -> 'product_id',json_element -> 'user_id',json_element -> 'item_count';
   	insert into orders (product_id,user_id,transaction_id,order_time,item_count,order_price,status) values((json_element -> 'product_id')::int,(json_element -> 'user_id')::integer, 1, current_timestamp,(json_element -> 'item_count')::integer,100,'success'); 
  END LOOP;
END;
$$;

insert into orders (product_id, user_id, transaction_id, order_time, item_count, order_price, status) values(2,1,1,current_timestamp,2,200,'success');

select * from orders;




/*
 * order_products(in order_json jsonb, in user_token varchar, out status_code int, out message varchar )
 * 
 * */

{
	"user_id": "", 
	"token": "", 
	"products": [
		
	]
}

select * from "session" s where session_status = 'active';

select order_products('[]','e85ae342-2f90-11ee-92cf-b37ee7cb9e23');

   -- 20- order products
CREATE OR REPLACE FUNCTION order_products(in order_json jsonb, in user_token varchar, out status_code int, out message varchar )
returns record
as $$
declare
json_element jsonb;
v_session_status_count int;
v_user_id int = 0;
v_user_count int;
v_user_role int;
v_user_balance NUMERIC(10, 2);
v_product_count int;
v_product_amount int;
v_total_price float4 :=0;
v_product_price float4 :=0;
v_order_price float4 :=0;
v_transaction_id int;
begin
	select user_id into v_user_id from "session" where token = user_token and session_status = 'active';
	select count(1) into v_user_count from "user" u where u.user_id = v_user_id;
	raise notice '%', v_user_id;
	   if v_user_count != 1 
		   then
				status_code := -9;
				message := 'order failed';
	   else
		   select count(1) into v_session_status_count from "session" where token = user_token and session_status = 'active';
		if v_session_status_count < 1 
			then
				status_code := -1;
				message := 'order failed';
		else
			select role_id into v_user_role from "user" where user_id = v_user_id;
				
			if v_user_role != 1
				then
					status_code := -2;
					message := 'order failed';
			else
				select b.balance into v_user_balance from balance b where b.user_id = v_user_id;
			
	
				for json_element in select jsonb_array_elements(order_json)
				loop
					select count(1) into v_product_count from product where product_id = (json_element -> 'product_id')::int and stock >= (json_element -> 'item_count')::int;
					if v_product_count < 1 
						then
							status_code := -3;
							message := 'order failed';
							insert into "transaction"(user_id, transaction_time, total_price, status) values(v_user_id, current_timestamp, v_total_price, 'failed');
							return;
					else
						select product_price into v_product_price from product where product_id = (json_element -> 'product_id')::int;
						v_order_price := (json_element -> 'item_count')::int * v_product_price;
						v_total_price = v_total_price + v_order_price;
						raise notice '%', v_order_price;
					end if;
				end loop;
	
	
				if v_total_price > v_user_balance
					then
						status_code := -4;
						message := 'order failed';
						insert into "transaction"(user_id, transaction_time, total_price, status) values(v_user_id, current_timestamp, v_total_price, 'failed');
						return;
					else if v_total_price <= 0
						then
							status_code := -5;
							message := 'order failed';
						return;
				else
					for json_element in select jsonb_array_elements(order_json)
					loop
						select product_price into v_product_price from product where product_id = (json_element -> 'product_id')::int;
						v_order_price := (json_element -> 'item_count')::int * v_product_price;
						insert into orders (product_id,user_id,transaction_id,order_time,item_count,order_price,status) values((json_element -> 'product_id')::int,(json_element -> 'user_id')::integer, 0, current_timestamp,(json_element -> 'item_count')::integer,v_order_price,'success'); 
						update product set stock = stock - (json_element -> 'item_count')::int where product_id = (json_element -> 'product_id')::int;
					end loop;
				end if;
			end if;
							
			
				update "balance" set balance = balance - v_total_price where user_id = v_user_id;
				insert into "transaction"(user_id, transaction_time, total_price, status) values(v_user_id, current_timestamp, v_total_price, 'success');
				select transaction_id into v_transaction_id from "transaction" order by transaction_time  desc limit 1;
				update orders set transaction_id = v_transaction_id where user_id = v_user_id and transaction_id = 0; 
				status_code := 0; 
				message := 'ordered successfully';
		end if;
			end if;
				end if;
end;
$$ LANGUAGE plpgsql;



select * from "user";
select * from "session" s 
;


create or replace function test(p_user_id character varying, p_token character varying , out status_code character varying,out status_message character varying) returns record language plpgsql as 
$$
declare
v_count numeric ;
priv_code varchar = 1;

begin 
	
	select count(1) into v_count  from "user" where user_id  = p_user_id::integer;

if v_count = 1 then
select count(1) into v_count from "session" s where user_id = p_user_id::integer and token  = p_token and session_status = 'active';
if v_count = 1 then
-- check privilege
status_code := '0';
status_message := 'success';
else
status_code := '-2';
status_message := 'user session not active';
end if;
else
status_code := '-1';
status_message := 'User Does not exist.';
end if;


	
end;

$$


select * from test('1', '81db2e16-35ed-11ee-9fad-ebdb76739d94');




SELECT SUBSTRING(md5(random()::text) FROM 1 FOR 8);
--SELECT crypt('mypassword', gen_salt('bf'));
CREATE EXTENSION IF NOT EXISTS pgcrypto;
SELECT encode(gen_random_bytes(8), 'base64');



create table privilege(
		privilege_id serial primary key,
		privilege_name varchar(200) unique not null
);

insert into privilege (privilege_name) values ('reset password');

create table role_privilege(
		role_id integer not null references "role",		
        privilege_id integer not null references "privilege"
);

insert into role_privilege (role_id, privilege_id) values (1, 1);

alter table "user" add column role_id int not null default 2;
update "user" set role_id = 1 where user_id = 1;


create table product(
		product_id serial primary key,
		product_name varchar(200) unique not null,
		product_desc varchar(200),
		product_price float4 not null,
		stock int not null default 0
);

create table orders(
		order_id serial primary key,
		product_id	int    not null references "product",
		user_id int      not null	references "user",
		transaction_id int not null references "transaction",
		order_time timestamp not null,
		item_count int not null default 1,
		order_price float4 not null
);

create table transaction(
		transaction_id serial primary key,
		user_id int      not null	references "user",
		transaction_time timestamp not null,
		total_price float4 not null default 0
);
ALTER TABLE orders ADD COLUMN status varchar NOT NULL DEFAULT 'failed';


