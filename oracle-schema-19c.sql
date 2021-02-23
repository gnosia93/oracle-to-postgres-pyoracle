-- alter session set container=PDB1;
alter session set "_ORACLE_SCRIPT"=true;
drop tablespace tbs_shop including contents and datafiles;
--create tablespace tbs_shop datafile '/u01/app/oracle/oradata/XE/tbs_shop.dbf' size 1G autoextend on;
create tablespace tbs_shop datafile size 1G autoextend on;

drop user shop cascade;
create user shop identified by shop
default tablespace tbs_shop
temporary tablespace temp;

grant create session, resource, dba  to shop;

--drop sequence shop.seq_product_product_id;
create sequence shop.seq_product_product_id
start with 1
increment by 1
cache 20;

--drop sequence shop.seq_comment_comment_id;
create sequence shop.seq_comment_comment_id
start with 1
increment by 1
cache 20;

--drop sequence shop.seq_order_order_id;
create sequence shop.seq_order_order_id
start with 1
increment by 1
nomaxvalue
nocycle
cache 20;


-- rownum 를 이용한 페이징 처리 체크.
-- lob 데이터 마이그 확인
-- 각종 데이터타입 변환 정보확인
-- display 의 경우 char, varchar로 서로 다름.

--drop table shop.tb_category;
create table shop.tb_category
(
   category_id       number(4) not null primary key,
   category_name     varchar(300) not null,
   display_yn        varchar(1) default 'Y' not null
);

--drop table shop.tb_product;
create table shop.tb_product
(
   product_id         number(9) not null,
   category_id        number(4) not null,
   name               varchar2(100) not null,
   price              number(19,3) not null,
   description        clob,
   image_data         blob,
   thumb_image_url    varchar2(300),
   image_url          varchar2(300),
   delivery_type      varchar2(10) not null,
   comment_cnt        number(9) default 0 not null,
   buy_cnt            number(9) default 0 not null,
   display_yn         char(1) default 'Y',
   reg_ymdt           date default sysdate not null,
   upd_ymdt           date,
   primary key(product_id)
);

create index shop.idx_product_01 on shop.tb_product(category_id, product_id);

--drop table shop.tb_comment;
create table shop.tb_comment
(
   comment_id         number not null,
   member_id          varchar2(30) not null,
   product_id         number(9) not null,
   score              varchar(1) not null,
   comment_body       varchar(4000),
   primary key(comment_id)
);

create index shop.idx_comment_01 on shop.tb_comment(member_id, comment_id);


-- order_no YYYYMMDD + serial(12자리) 어플리케이션에서 발행(프로시저로 만듬)
-- 체크 제약조건이 제대로 변환되는지 확인한다.

--drop table shop.tb_order;
create table shop.tb_order
(
   order_no                varchar2(20) not null primary key,
   member_id               varchar2(30) not null,
   order_price             number(19,3) not null,
   order_ymdt              date default sysdate,
   pay_status              varchar2(10) not null,
   pay_ymdt                date,
   error_ymdt              date,
   error_message           date,
   error_cd                varchar2(3),
   constraint check_pay_status
   check(pay_status in ('Queued', 'Processing', 'error', 'Completed'))
);


--drop table shop.tb_order_detail;
create table shop.tb_order_detail
(
   order_no                varchar2(20) not null,
   product_id              number(9),
   product_price           number(19,3) not null,
   product_cnt             number,
   primary key(order_no, product_id)
);


--drop table shop.tb_product_summary;
create table shop.tb_product_summary
(
   year           varchar2(4) not null,
   month          varchar2(2) not null,
   day            varchar2(2) not null,
   hour           varchar2(2) not null,
   min            varchar2(2) not null,
   product_id     number(9) not null,
   order_cnt      number not null,
   total_price    number not null,
   comment_cnt    number not null,
   primary key(year, month, day, hour, min, product_id)
);


--drop table shop.tb_sct_typeconv;
create table shop.tb_sct_typeconv
(
   num              number,
   num1             number(1),
   num8             number(8),
   num9             number(9),
   num10            number(10),
   num11            number(11),
   num18            number(18),
   num19            number(19),
   num20            number(20),
   num30            number(30),
   num38            number(38),
   num10_3          number(10, 3),
   num38_4          number(38, 4),
   long_col         long,
   float_col1       float,
   float_col10      float(10),
   float_col20      float(20),
   chr1             char(1),
   chr2             char(2),
   chr3             char(2000),
   str1             varchar2(1),
   str4000          varchar2(4000),
   date_col         date,
   timestamp_col    timestamp,
   nchar_col        nchar(1),
   nvarchar         nvarchar2(100),
   nclob_col        nclob,
   bfile_col        bfile
);

--drop table shop.tb_order_summary;
create table shop.tb_order_summary
(
    order_no        varchar2(20) not null unique,
    product_cnt     number(9),
    reg_ymdt        timestamp
);


-- added 2021/02/01
-- trigger
create or replace trigger shop.tr_after_insert_order
after insert on shop.tb_order
for each row
declare
    v_product_cnt   number;
    v_order_no      tb_order.order_no%type;
begin
    dbms_output.put_line('tr_after_insert_order executed...');

  --  v_order_no :=

  --  select count(1) into v_product_cnt
  --  from shop.tb_order o, shop.tb_order_detail d
  --  where o.order_no = d.order_no
  --    and o.order_no = :new.order_no;


    -- 실행시 권한 오류로 인해 임시적으로 주서처리 함. 원인은 알수 없음 ㅜㅜ
    --insert into shop.tb_order_summary values(:NEW.order_no, v_product_cnt, sysdate);
end;
/


-- view
create or replace view shop.view_recent_order_30 as
select name, order_no, member_id, order_price, order_ymdt
from (
    select rownum as rn, p.name, o.order_no, o.member_id, o.order_price, o.order_ymdt
    from shop.tb_order o, shop.tb_order_detail d, shop.tb_product p
    where o.order_no = d.order_no
      and d.product_id = p.product_id
    order by o.order_ymdt desc
)
where rn between 1 and 30;

-- function
-- DROP FUNCTION shop.get_product_id;
CREATE OR REPLACE FUNCTION shop.get_product_id
RETURN VARCHAR2
IS
    v_today           VARCHAR2(8);
    v_sub_order_no    VARCHAR(12);
BEGIN

    select to_char(sysdate, 'yyyymmdd') into v_today from dual;
    select lpad(shop.seq_order_order_id.nextval, 12, '0') into v_sub_order_no from dual;

    return v_today || v_sub_order_no;
END;
/

-- procedure
-- outer join example
CREATE OR REPLACE PROCEDURE shop.sp_product_summary(v_interval in number)
IS
    v_cnt NUMBER := 0;
BEGIN
    -- truncate table.
    execute immediate 'truncate table test_table';

    insert into shop.tb_product_summary
    select to_char(o.order_ymdt, 'yyyy') as year,
        to_char(o.order_ymdt, 'mm') as month,
        to_char(o.order_ymdt, 'dd') as day,
        to_char(o.order_ymdt, 'hh') as hour,
        to_char(o.order_ymdt, 'mm') as min,
        p.product_id,
        count(1) as order_cnt,
        sum(d.product_price) as total_price,
        max(c.comment_cnt) as comment_cnt
    from
        shop.tb_order o,
        shop.tb_order_detail d,
        shop.tb_product p,
        (select product_id, count(1) as comment_cnt
         from shop.tb_comment
         group by product_id) c
    where o.order_no = d.order_no
      and d.product_id = p.product_id
      and p.product_id = c.product_id(+)
    group by to_char(o.order_ymdt, 'yyyy'),
        to_char(o.order_ymdt, 'mm'),
        to_char(o.order_ymdt, 'dd'),
        to_char(o.order_ymdt, 'hh'),
        to_char(o.order_ymdt, 'mm'),
        p.product_id;

    COMMIT;
END;
/

-- this code doesn't work so don't execute this.
-- loop example
-- DROP PROCEDURE SHOP.LOAD_DATA;
CREATE OR REPLACE PROCEDURE SHOP.LOAD_DATA(rowcnt IN NUMBER)
IS
    v_cnt NUMBER := 0;
    v_price NUMBER := 0;
    v_delivery_cd NUMBER := 0;
    v_delivery_type VARCHAR2(10);
    v_image_url VARCHAR2(300);
    v_random int;
BEGIN

    LOOP
        v_cnt := v_cnt + 1;

        BEGIN
            v_price := (MOD(v_cnt, 10) + 1) * 1000;
            select round(dbms_random.value(1,10)) into v_random from dual;

            IF v_random = 1 THEN
                v_delivery_type := 'Free';
            ELSE
                v_delivery_type := 'Charged';
            END IF;

            v_image_url := 'https://ocktank-prod-image.s3.ap-northeast-2.amazonaws.com/jeans/jean-' || v_random || '.png';

            INSERT INTO SHOP.TB_PRODUCT(product_id, name, price, description, delivery_type, image_url)
                VALUES(SHOP.seq_product_product_id.nextval,
                      'ocktank 청바지' || SHOP.seq_product_product_id.currval,
                      v_price,
                      '청바지 전문!!!',
                      v_delivery_type,
                      v_image_url);
        EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Exception ..');
        END;

        IF MOD(v_cnt, 1000) = 0 THEN
            COMMIT;
        END IF;

        EXIT WHEN v_cnt >= rowcnt;

    END LOOP;
    COMMIT;
END;
/

quit