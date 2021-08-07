"""
    author: soonbeom@amazon.com
    description :
        oracle database initialization script which includes following tables
        tb_product
        tb_order
        tb_order_detail
        tb_comment
"""
import cx_Oracle
import datetime
import random
import configparser
import threading,sys

config = configparser.ConfigParser()
config.read('config.ini')

ORACLE_11XE_URL = config['DEFAULT']['ORACLE_11XE_URL']
ORACLE_19C_URL = config['DEFAULT']['ORACLE_19C_URL']
ORACLE_DB_URL = ""

DATA_PATH = config['DEFAULT']['DATA_PATH']
DEFAULT_PRODUCT_COUNT = int(config['DEFAULT']['DEFAULT_PRODUCT_COUNT'])
DEFAULT_ORDER_COUNT = int(config['DEFAULT']['DEFAULT_ORDER_COUNT'])
PRODUCT_DESCRIPTION_HTML_PATH = DATA_PATH + "/product_body.html"
NUMBER_OF_ORDER_CLIENT = int(config['DEFAULT']['NUMBER_OF_ORDER_CLIENT'])

# global variable for product id
(minProductId, maxProductId) = (0, 0)

class Database:
    def __init__(self):
        self.conn = cx_Oracle.connect(ORACLE_DB_URL)
        self.cursor = self.conn.cursor()

    def save(self, sql, t = None):
        if t is None:
            self.cursor.execute(sql)
        else :
            self.cursor.execute(sql, t)

    def query(self, sql):
        self.cursor.execute(sql)

    def fetchOne(self):
        return self.cursor.fetchone()

    def commit(self):
        self.conn.commit()

    def closeCursor(self):
        self.cursor.close()

    def close(self):
        self.conn.close()

def getOrderMember():
    return 'user' + str(random.randint(1, 10000)).zfill(3)

def getRandomCatogoryId():
    return random.randint(1, 20)

def getRandomProductId():
    global minProductId, maxProductId
    return random.randint(minProductId, maxProductId)

def getRandomCommentScore():
    return random.randint(1, 5)

def getRandomOrderProductCount():
    return random.randint(1, 5)


class Product:
    def __init__(self, database):
        self.database = database

    def newProduct(self):
        sql = "select shop.seq_product_product_id.nextval from dual"
        self.database.query(sql)
        (productId,) = self.database.fetchOne()

        filename = str(productId % 20 + 1) + ".jpg"
        imageFilePath = DATA_PATH + "/" + filename
        with open(PRODUCT_DESCRIPTION_HTML_PATH, "r") as f, open(imageFilePath, "rb") as w:
            productDescription = f.read()            # description is clob
            productImage = w.read()                  # image_data is blob
            imageUrl = 'https://demo-database-postgres.s3.ap-northeast-2.amazonaws.com/images/{filename}'.format(filename = filename)

            productTuple = (productId, getRandomCatogoryId(), 'product#' + str(productId), 100, 'A', productDescription, productImage, imageUrl)
            sql = "insert into shop.tb_product(product_id, category_id, name, price, delivery_type, description, image_data, image_url) " \
                  "values(:1, :2, :3, :4, :5, :6, :7, :8)"
            self.database.save(sql, productTuple)
            self.database.commit()

    def getProductIdRange(self):
        sql = "select min(product_id) as low_product_id, max(product_id) as high_product_id from shop.tb_product"
        self.database.query(sql)
        (startProductId, endProductId) = self.database.fetchOne()
        return (startProductId, endProductId)


class Comment:
    def __init__(self, database):
        self.database = database

    def newComment(self):
        sql = "select shop.seq_comment_comment_id.nextval from dual"
        self.database.query(sql)
        (commentId,) = self.database.fetchOne()

        memberId = getOrderMember()
        productId = getRandomProductId()
        score = getRandomCommentScore()
        commentBody = "................... comment" + str(commentId)
        commentTuple = (commentId, memberId, productId, score, commentBody)

        sql = "insert into shop.tb_comment(comment_id, member_id, product_id, score, comment_body) values(:1, :2, :3, :4, :5)"
        self.database.save(sql, commentTuple)
        self.database.commit()

class Order:
    def __init__(self, database):
        self.database = database

    def getCurrentDate(self):
        now = datetime.datetime.now()
        return now.strftime('%Y%m%d')

    def getRandomOrderDetailCount(self):
        return random.randint(1, 5)

    def getOrderNo(self):
        sql = "select shop.seq_order_order_id.nextval from dual"
        self.database.query(sql)
        (orderNo,) = self.database.fetchOne()

        return self.getCurrentDate() + str(orderNo).zfill(12)

    def newOrder(self):
        orderNo = self.getOrderNo()

        # 세부 항목 부터 입력.
        for i in range(self.getRandomOrderDetailCount()):
            try:
                itemTuple = (orderNo, getRandomProductId(), 1000, getRandomOrderProductCount())
                sql = "insert into shop.tb_order_detail(order_no, product_id, product_price, product_cnt) values(:1, :2, :3, :4)"
                self.database.save(sql, itemTuple)
            except:
                pass    # getRandomProductId() 값이 중복인 경우 그냥 skip 한다.

        # 주문 정보 입력
        sql = "insert into shop.tb_order(order_no, member_id, order_price, pay_status, pay_ymdt) " \
              "select '{orderNo}' as order_no, " \
              "'{memberId}' as member_id, " \
              "sum(product_price*product_cnt) as order_price, " \
              "'Completed' as pay_status, " \
              "sysdate as pay_ymdt " \
              "from tb_order_detail " \
              "where order_no = '{orderNo}'".format(orderNo=orderNo, memberId=getOrderMember())

        #print(sql)
        self.database.save(sql)
        self.database.commit()


    def updateOrder(self):
        """
            주문 또는 주문 상세값을 수정하여, postgresql의 Vaccumm 을 관찰한다.
        """
        pass

def display(step):
    if step % 100 == 0:
        print('*', end ='', flush=True)

def initProduct():
    database = Database()
    product = Product(database)

    # initialize product table
    print("initilize product table... ")
    for epoch in range(DEFAULT_PRODUCT_COUNT):
        product.newProduct()
        display(epoch)
    database.close()

def makeOrder(number):
    database = Database()
    order = Order(database)
    comment = Comment(database)
    product = Product(database)

    # update global variables
    global minProductId, maxProductId
    (minProductId, maxProductId) = product.getProductIdRange()
    print((minProductId, maxProductId))

    # initialize order & comment
    print("loading order & comment table...")
    for epoch in range(DEFAULT_ORDER_COUNT):
        order.newOrder()
        if epoch % 100 == 0:    # comment writing
            comment.newComment()
        display(epoch)          # flush * every 1000 order

    database.close()

def verbose():
    print('ORACLE_DB_URL:', ORACLE_DB_URL)
    print('DATA_PATH', DATA_PATH)
    print('PRODUCT_DESCRIPTION_HTML_PATH:', DATA_PATH + "/product_body.html")
    print('DEFAULT_PRODUCT_COUNT:', DEFAULT_PRODUCT_COUNT)
    print('DEFAULT_ORDER_COUNT:', DEFAULT_ORDER_COUNT)
    print('NUMBER_OF_ORDER_CLIENT:', NUMBER_OF_ORDER_CLIENT)

if __name__ == '__main__':

    if len(sys.argv) > 1:
        dbVersion = sys.argv[1]
        if dbVersion == '11xe':
            ORACLE_DB_URL = ORACLE_11XE_URL
        else:
            ORACLE_DB_URL = ORACLE_19C_URL

    verbose()
    initProduct()
    for i in range(1, NUMBER_OF_ORDER_CLIENT):
        orderThread = threading.Thread(target=makeOrder, args=(i,))
        orderThread.start()


