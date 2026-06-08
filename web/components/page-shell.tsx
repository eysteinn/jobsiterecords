import styles from "./page-shell.module.css";

type Props = {
  title: string;
  subtitle: string;
  action?: React.ReactNode;
  children: React.ReactNode;
  className?: string;
};

export function PageShell({ title, subtitle, action, children, className }: Props) {
  return (
    <div className={className ? `${styles.page} ${className}` : styles.page}>
      <div className={styles.header}>
        <div>
          <h1>{title}</h1>
          <p>{subtitle}</p>
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
