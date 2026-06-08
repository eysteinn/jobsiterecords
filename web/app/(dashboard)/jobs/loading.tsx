import styles from "./loading.module.css";

export default function JobsLoading() {
  return (
    <div className={styles.wrap}>
      <div className={`${styles.searchSkeleton} mobileOnly`} />
      <div className={`${styles.searchSkeleton} desktopOnly`} />
      <div className={styles.cardSkeleton} />
      <div className={styles.cardSkeleton} />
      <div className={styles.cardSkeleton} />
    </div>
  );
}
