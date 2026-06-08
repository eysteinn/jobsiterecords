import styles from "./page-shell.module.css";

type Props = {
  title: React.ReactNode;
  subtitle?: React.ReactNode;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
  headerClassName?: string;
};

export function PageShell({ title, subtitle, action, children, className, headerClassName }: Props) {
  return (
    <div className={className ? `${styles.page} ${className}` : styles.page}>
      <div className={headerClassName ? `${styles.header} ${headerClassName}` : styles.header}>
        <div className={styles.headerText}>
          <h1>{title}</h1>
          {subtitle != null && subtitle !== "" && <p>{subtitle}</p>}
        </div>
        {action}
      </div>
      {children}
    </div>
  );
}

export function EmptyState({
  title,
  description,
}: {
  title: string;
  description: string;
}) {
  return (
    <div className={styles.empty}>
      <h2>{title}</h2>
      <p>{description}</p>
    </div>
  );
}
