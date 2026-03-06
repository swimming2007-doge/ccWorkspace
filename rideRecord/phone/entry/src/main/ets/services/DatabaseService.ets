/**
 * 数据库服务
 *
 * 功能说明：
 * - SQLite 数据库初始化
 * - 表创建和管理
 * - 基础 CRUD 操作封装
 * - 事务支持
 *
 * 技术栈：
 * - @ohos.data.relationalStore 鸿蒙关系型数据库
 */
import relationalStore from '@ohos.data.relationalStore';
import hilog from '@ohos.hilog';
import { DB_CONFIG, CREATE_TABLES, INIT_ORDER, createTrackPointsTableForMonth, createTrackPointsMonthIndex } from '../../../src/schema/database';

const TAG = '[DatabaseService]';
const DOMAIN = 0xFF00;

/**
 * 数据库服务类
 */
export class DatabaseService {
  private rdbStore: relationalStore.RdbStore | null = null;
  private isInitialized: boolean = false;

  /**
   * 初始化数据库
   */
  async initialize(context: Context): Promise<void> {
    if (this.isInitialized) {
      hilog.warn(DOMAIN, TAG, 'Database already initialized');
      return;
    }

    hilog.info(DOMAIN, TAG, 'Initializing database');

    try {
      // 创建数据库配置
      const config: relationalStore.StoreConfig = {
        name: DB_CONFIG.name,
        securityLevel: relationalStore.SecurityLevel.S1
      };

      // 获取 RdbStore 实例
      this.rdbStore = await relationalStore.getRdbStore(context, config);

      // 创建表
      await this.createTables();

      this.isInitialized = true;
      hilog.info(DOMAIN, TAG, 'Database initialized successfully');

    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to initialize database: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 创建所有表
   */
  private async createTables(): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    hilog.info(DOMAIN, TAG, 'Creating tables');

    for (const tableName of INIT_ORDER) {
      const sql = (CREATE_TABLES as Record<string, string>)[tableName];
      if (sql) {
        try {
          await this.rdbStore.executeSql(sql);
          hilog.debug(DOMAIN, TAG, 'Table created: %{public}s', tableName);
        } catch (error) {
          hilog.error(DOMAIN, TAG, 'Failed to create table %{public}s: %{public}s',
            tableName, JSON.stringify(error));
        }
      }
    }
  }

  /**
   * 创建月度轨迹点表
   */
  async createTrackPointsTable(year: number, month: number): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    const createSql = createTrackPointsTableForMonth(year, month);
    const indexSql = createTrackPointsMonthIndex(year, month);

    try {
      await this.rdbStore.executeSql(createSql);
      await this.rdbStore.executeSql(indexSql);
      hilog.info(DOMAIN, TAG, 'Track points table created for %{public}d-%{public}d', year, month);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Failed to create track points table: %{public}s', JSON.stringify(error));
    }
  }

  /**
   * 插入数据
   */
  async insert(tableName: string, values: relationalStore.ValuesBucket): Promise<number> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      const rowId = await this.rdbStore.insert(tableName, values);
      hilog.debug(DOMAIN, TAG, 'Inserted into %{public}s, rowId: %{public}d', tableName, rowId);
      return rowId;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Insert failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 批量插入数据
   */
  async batchInsert(tableName: string, valuesList: relationalStore.ValuesBucket[]): Promise<number> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      const rowIds = await this.rdbStore.batchInsert(tableName, valuesList);
      hilog.debug(DOMAIN, TAG, 'Batch inserted into %{public}s, count: %{public}d', tableName, rowIds);
      return rowIds;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Batch insert failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 更新数据
   */
  async update(
    tableName: string,
    values: relationalStore.ValuesBucket,
    predicates: relationalStore.RdbPredicates
  ): Promise<number> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      const changedRows = await this.rdbStore.update(values, predicates);
      hilog.debug(DOMAIN, TAG, 'Updated %{public}s, changed rows: %{public}d', tableName, changedRows);
      return changedRows;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Update failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 删除数据
   */
  async delete(tableName: string, predicates: relationalStore.RdbPredicates): Promise<number> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      const deletedRows = await this.rdbStore.delete(predicates);
      hilog.debug(DOMAIN, TAG, 'Deleted from %{public}s, deleted rows: %{public}d', tableName, deletedRows);
      return deletedRows;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Delete failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 查询数据
   */
  async query(
    predicates: relationalStore.RdbPredicates,
    columns?: string[]
  ): Promise<relationalStore.ResultSet> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      const resultSet = await this.rdbStore.query(predicates, columns);
      hilog.debug(DOMAIN, TAG, 'Query executed, row count: %{public}d', resultSet.rowCount);
      return resultSet;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Query failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 执行 SQL 查询
   */
  async querySql(sql: string, args?: string[]): Promise<relationalStore.ResultSet> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      const resultSet = await this.rdbStore.querySql(sql, args);
      return resultSet;
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Query SQL failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 执行 SQL 语句
   */
  async executeSql(sql: string, args?: string[]): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }

    try {
      await this.rdbStore.executeSql(sql, args);
    } catch (error) {
      hilog.error(DOMAIN, TAG, 'Execute SQL failed: %{public}s', JSON.stringify(error));
      throw error;
    }
  }

  /**
   * 开始事务
   */
  async beginTransaction(): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }
    this.rdbStore.beginTransaction();
  }

  /**
   * 提交事务
   */
  async commit(): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }
    this.rdbStore.commit();
  }

  /**
   * 回滚事务
   */
  async rollBack(): Promise<void> {
    if (!this.rdbStore) {
      throw new Error('Database not initialized');
    }
    this.rdbStore.rollBack();
  }

  /**
   * 获取 RdbStore 实例
   */
  getStore(): relationalStore.RdbStore | null {
    return this.rdbStore;
  }

  /**
   * 检查是否已初始化
   */
  isReady(): boolean {
    return this.isInitialized && this.rdbStore !== null;
  }

  /**
   * 关闭数据库
   */
  async close(): Promise<void> {
    if (this.rdbStore) {
      try {
        await relationalStore.deleteRdbStore({}, DB_CONFIG.name);
        this.rdbStore = null;
        this.isInitialized = false;
        hilog.info(DOMAIN, TAG, 'Database closed');
      } catch (error) {
        hilog.error(DOMAIN, TAG, 'Failed to close database: %{public}s', JSON.stringify(error));
      }
    }
  }
}

// 导出单例
export default new DatabaseService();
