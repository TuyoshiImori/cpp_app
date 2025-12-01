import type { Timestamp } from "firebase/firestore";
import { QuestionType } from "./questionType";

/**
 * 個人情報設問で保持する項目フラグ
 * 各フィールドが true の場合、その項目をアンケートで取得する
 */
export interface InfoFields {
  furigana?: boolean;
  name?: boolean;
  nameWithFurigana?: boolean;
  email?: boolean;
  phone?: boolean;
  postalCode?: boolean;
  address?: boolean;
}

/**
 * 設問の型
 * - 選択系はoptionsを持つ
 * - info は InfoFields を持つ
 */
export interface FirestoreQuestion {
  index: number;
  type: QuestionType;
  // 単一/複数選択の場合の選択肢
  options?: string[];
  // 個人情報設問の場合の取得項目
  infoFields?: InfoFields;
}

/**
 * アンケートドキュメント
 */
export interface FirestoreSurveyDocument {
  id: string;
  title: string;
  questions: FirestoreQuestion[];
  createdAt?: Timestamp;
  updatedAt?: Timestamp;
}
