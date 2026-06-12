import { STUDENT_ACCOUNTS } from '../data/AccountData';
import { StudentAccount, User } from '../models/FaceCheckModels';
import { PreferenceStore } from './PreferenceStore';

export class AccountService {
  private static store?: PreferenceStore;
  private static accounts: StudentAccount[] = [...STUDENT_ACCOUNTS];
  private static initialized: boolean = false;

  static init(store: PreferenceStore): void {
    AccountService.store = store;
    AccountService.loadAccountsFromStorage();
    AccountService.initialized = true;
  }

  static login(studentId: string, password: string): StudentAccount | undefined {
    return AccountService.accounts.find((account: StudentAccount) => {
      return account.studentId === studentId && account.password === password;
    });
  }

  static userByStudentId(studentId: string): User | undefined {
    const account = AccountService.accounts.find((item: StudentAccount) => item.studentId === studentId);
    return account ? account.user : undefined;
  }

  static register(studentId: string, name: string, className: string, academy: string, password: string): boolean {
    // 检查学号是否已存在
    if (AccountService.accounts.some((account: StudentAccount) => account.studentId === studentId)) {
      return false;
    }

    // 创建新用户
    const newUser: User = {
      userId: `u-${studentId}`,
      name: name,
      studentId: studentId,
      className: className,
      academy: academy,
      faceRegistered: false
    };

    // 创建新账户
    const newAccount: StudentAccount = {
      studentId: studentId,
      password: password,
      user: newUser
    };

    // 添加到账户列表
    AccountService.accounts.push(newAccount);

    // 保存到本地存储
    AccountService.saveAccountsToStorage();

    return true;
  }

  static saveAccountsToStorage(): void {
    try {
      if (AccountService.store) {
        AccountService.store.saveAccounts(AccountService.accounts);
        console.log('保存账户数据:', AccountService.accounts.length);
      } else {
        console.warn('PreferenceStore 未初始化，无法保存账户数据');
      }
    } catch (err) {
      console.error('保存账户数据失败:', err);
    }
  }

  static loadAccountsFromStorage(): void {
    try {
      if (AccountService.store) {
        const savedAccounts: StudentAccount[] = AccountService.store.accounts();
        if (savedAccounts.length > 0) {
          // 直接使用保存的账户数据
          AccountService.accounts = savedAccounts;
          console.log('加载账户数据:', AccountService.accounts.length);
        } else {
          // 首次使用，保存默认账户
          AccountService.accounts = [...STUDENT_ACCOUNTS];
          AccountService.saveAccountsToStorage();
          console.log('首次使用，初始化默认账户');
        }
      } else {
        console.warn('PreferenceStore 未初始化，使用默认账户');
        AccountService.accounts = [...STUDENT_ACCOUNTS];
      }
    } catch (err) {
      console.error('加载账户数据失败:', err);
      AccountService.accounts = [...STUDENT_ACCOUNTS];
    }
  }

  static updateAvatar(studentId: string, avatarPath: string): boolean {
    const account = AccountService.accounts.find((item: StudentAccount) => item.studentId === studentId);
    if (!account) {
      return false;
    }
    account.user.avatarPath = avatarPath;
    AccountService.saveAccountsToStorage();
    return true;
  }

  static getAvatarPath(studentId: string): string | undefined {
    const account = AccountService.accounts.find((item: StudentAccount) => item.studentId === studentId);
    return account ? account.user.avatarPath : undefined;
  }
}
